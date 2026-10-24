#!/bin/bash
# =============================================================================
# Xcode Cloud: Skript nach dem Klonen des Repositorys (ci_post_clone.sh)
#
# Xcode Cloud führt dieses Skript bei JEDER Aktion des Workflows (Test,
# Archive) direkt nach dem Klonen aus – vor xcodebuild. Arbeitsverzeichnis ist
# ci_scripts/, der Quellcode liegt unter $CI_PRIMARY_REPOSITORY_PATH.
#
# Aufgaben:
#   1. Nur in der temporären Cloud-Kopie (das Repository bleibt unverändert):
#      Team-ID, Versionsnummer und Build-Nummer in project.yml eintragen.
#   2. XcodeGen laden und das Xcode-Projekt aus project.yml erzeugen
#      (die Projektdatei ist nicht eingecheckt, siehe .gitignore).
#   3. Swift-Pakete (z. B. GRDB) auflösen. Xcode Cloud lädt Pakete nicht
#      selbst nach, sondern verlangt eine fertige Package.resolved – die
#      entsteht hier, weil das Projekt erst in der Cloud erzeugt wird.
#
# Es werden keine Geheimnisse benötigt: Xcode Cloud signiert mit dem
# Apple-Konto des Teams (fastlane bleibt nur für den GitHub-Ausweichweg).
#
# Build-Nummer: App Store Connect übernimmt beim Verteilen über TestFlight
# IMMER die Xcode-Cloud-Buildnummer (CI_BUILD_NUMBER). Damit sie über den
# letzten fastlane-Upload hinaus weiterzählt, ist in App Store Connect →
# Xcode Cloud → Produkt → Einstellungen → Build-Nummer die „Nächste
# Build-Nummer“ gesetzt. Die Prüfung unten bricht ein Archiv mit kleinerer
# Nummer früh ab, statt dass Apple den Upload erst nach dem Bauen ablehnt.
# =============================================================================
set -euo pipefail

# --- Angaben zu dieser App ---------------------------------------------------
PROJEKT="Hachibu"                # Name der erzeugten .xcodeproj
SCHEMA="Hachibu"                 # gemeinsames Schema aus project.yml
MINDEST_BUILDNUMMER=101          # letzter fastlane-Upload: Build 100

# XcodeGen in fester Version und mit Prüfsumme.
XCODEGEN_VERSION="2.46.0"
XCODEGEN_SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"

REPO="${CI_PRIMARY_REPOSITORY_PATH:?CI_PRIMARY_REPOSITORY_PATH fehlt – das Skript ist für Xcode Cloud gedacht.}"
cd "$REPO"

# Homebrew (nur Ausweichweg) soll sich nicht erst selbst aktualisieren.
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_ENV_HINTS=1
# XcodeGen benötigt die Umgebungsvariable USER; in manchen Umgebungen fehlt sie.
export USER="${USER:-$(id -un)}"

echo "Xcode Cloud: Workflow '${CI_WORKFLOW:-?}', Aktion '${CI_XCODEBUILD_ACTION:-?}', Build ${CI_BUILD_NUMBER:-?}, Start '${CI_START_CONDITION:-?}', Branch '${CI_BRANCH:-–}', Tag '${CI_TAG:-–}'"

# -----------------------------------------------------------------------------
# 1. Versionsnummern und Team-ID in die Cloud-Kopie von project.yml schreiben
# -----------------------------------------------------------------------------

# Ersetzt den Wert einer vorhandenen Einstellung "SCHLUESSEL: ..." in project.yml.
# Bricht ab, wenn die Zeile nicht genau einmal vorkommt.
setze_einstellung() {
    local schluessel="$1" wert="$2" anzahl
    anzahl="$(grep -cE "^[[:space:]]*${schluessel}:" project.yml || true)"
    if [ "$anzahl" != "1" ]; then
        echo "error: ${schluessel} steht ${anzahl}-mal statt genau einmal in project.yml." >&2
        exit 1
    fi
    sed -i '' -E "s/^([[:space:]]*${schluessel}:).*/\1 \"${wert}\"/" project.yml
}

# Versionsnummer: bei einem Tag v1.2.3 (oder ios-v1.2.3) -> 1.2.3, sonst der Wert aus project.yml.
if [ -n "${CI_TAG:-}" ]; then
    VERSION="${CI_TAG#ios-}"
    VERSION="${VERSION#v}"
    if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+(\.[0-9]+){1,2}$'; then
        echo "error: Ungültige Versionsnummer '$VERSION' aus Tag '$CI_TAG'. Erwartet wird ein Tag wie v1.2.3." >&2
        exit 1
    fi
    setze_einstellung MARKETING_VERSION "$VERSION"
fi

# Build-Nummer: dieselbe Nummer, die App Store Connect beim Verteilen verwendet.
BUILDNUMMER="${CI_BUILD_NUMBER:?CI_BUILD_NUMBER fehlt}"
if [ "${CI_XCODEBUILD_ACTION:-}" = "archive" ] && [ "$BUILDNUMMER" -lt "$MINDEST_BUILDNUMMER" ]; then
    echo "error: Xcode-Cloud-Build ${BUILDNUMMER} ist kleiner als ${MINDEST_BUILDNUMMER}; Apple würde den Upload ablehnen." >&2
    echo "error: In App Store Connect → Xcode Cloud → ${PROJEKT} → Einstellungen → Build-Nummer die „Nächste Build-Nummer“ auf ${MINDEST_BUILDNUMMER} setzen und neu starten." >&2
    exit 1
fi
setze_einstellung CURRENT_PROJECT_VERSION "$BUILDNUMMER"

# Team-ID: Xcode Cloud stellt die Team-ID des Workflows als CI_TEAM_ID bereit.
# Steht DEVELOPMENT_TEAM schon in project.yml, wird der Wert ersetzt, sonst wird
# die Zeile direkt nach CODE_SIGN_STYLE mit derselben Einrückung eingefügt.
if [ -n "${CI_TEAM_ID:-}" ]; then
    if grep -qE '^[[:space:]]*DEVELOPMENT_TEAM:' project.yml; then
        setze_einstellung DEVELOPMENT_TEAM "$CI_TEAM_ID"
    else
        awk -v team="$CI_TEAM_ID" '
            { print }
            !eingefuegt && /^[[:space:]]*CODE_SIGN_STYLE:/ {
                match($0, /^[[:space:]]*/)
                printf "%sDEVELOPMENT_TEAM: \"%s\"\n", substr($0, 1, RLENGTH), team
                eingefuegt = 1
            }
        ' project.yml > project.yml.neu
        mv project.yml.neu project.yml
    fi
    grep -q "DEVELOPMENT_TEAM: \"$CI_TEAM_ID\"" project.yml || { echo "error: DEVELOPMENT_TEAM konnte nicht in project.yml eingetragen werden." >&2; exit 1; }
fi

echo "Einstellungen für diesen Build:"
grep -E '^[[:space:]]*(MARKETING_VERSION|CURRENT_PROJECT_VERSION|DEVELOPMENT_TEAM|CODE_SIGN_STYLE):' project.yml

# -----------------------------------------------------------------------------
# 2. XcodeGen laden und das Xcode-Projekt erzeugen
# -----------------------------------------------------------------------------
WERKZEUGE="$(mktemp -d)"
if curl -fsSL --retry 3 -o "$WERKZEUGE/xcodegen.zip" \
        "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip" \
   && echo "${XCODEGEN_SHA256}  $WERKZEUGE/xcodegen.zip" | shasum -a 256 -c - >/dev/null \
   && unzip -q "$WERKZEUGE/xcodegen.zip" -d "$WERKZEUGE"; then
    XCODEGEN="$WERKZEUGE/xcodegen/bin/xcodegen"
else
    echo "warning: XcodeGen ${XCODEGEN_VERSION} ließ sich nicht laden oder die Prüfsumme stimmt nicht – Ausweichweg über Homebrew."
    brew install xcodegen
    XCODEGEN="$(command -v xcodegen)"
fi
echo "XcodeGen-Version: $("$XCODEGEN" --version)"
"$XCODEGEN" generate --spec project.yml

test -d "${PROJEKT}.xcodeproj" || { echo "error: ${PROJEKT}.xcodeproj wurde nicht erzeugt – project.yml prüfen." >&2; exit 1; }
test -f "${PROJEKT}.xcodeproj/xcshareddata/xcschemes/${SCHEMA}.xcscheme" \
    || { echo "error: Gemeinsames Schema ${SCHEMA} fehlt – project.yml (schemes) prüfen." >&2; exit 1; }
echo "Erzeugt: ${PROJEKT}.xcodeproj mit gemeinsamem Schema ${SCHEMA}"

# -----------------------------------------------------------------------------
# 3. Swift-Pakete auflösen (schreibt Package.resolved ins erzeugte Projekt)
# -----------------------------------------------------------------------------
if grep -qE '^packages:' project.yml; then
    xcodebuild -resolvePackageDependencies -project "${PROJEKT}.xcodeproj" -scheme "$SCHEMA"
fi

echo "ci_post_clone.sh fertig."
