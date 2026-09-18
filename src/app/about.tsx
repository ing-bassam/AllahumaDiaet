import { useRouter } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { useState, type ReactNode } from 'react';
import { Alert, Linking, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { APP_NAME, APP_VERSION } from '../appInfo';
import { Icon } from '../components/Icon';
import { PrimaryButton } from '../components/PrimaryButton';
import { deleteAllData } from '../db/repository';
import { IMPRINT, LEGAL_URLS } from '../legal/imprint';
import licenses from '../legal/licenses.json';
import { CALCULATION_SOURCES, CALCULATION_STEPS, MEDICAL_DISCLAIMER } from '../legal/sources';
import { colors, radius, spacing } from '../theme';

async function openLink(url: string) {
  try {
    await Linking.openURL(url);
  } catch {
    const target = url.startsWith('mailto:') ? url.slice('mailto:'.length) : url;
    Alert.alert('Link konnte nicht geöffnet werden', target);
  }
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <View style={styles.card}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {children}
    </View>
  );
}

function LinkText({ label, url }: { label: string; url: string }) {
  return (
    <Text style={styles.link} suppressHighlighting onPress={() => openLink(url)} accessibilityRole="link">
      {label}
    </Text>
  );
}

export default function About() {
  const db = useSQLiteContext();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const [showLicenses, setShowLicenses] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const confirmDeleteAll = () => {
    Alert.alert('Alle Daten löschen?', 'Profil, Einträge und gespeicherte Produkte werden unwiderruflich gelöscht.', [
      { text: 'Abbrechen', style: 'cancel' },
      {
        text: 'Löschen',
        style: 'destructive',
        onPress: async () => {
          setDeleting(true);
          try {
            await deleteAllData(db);
            router.replace('/onboarding');
          } catch {
            setDeleting(false);
            Alert.alert('Löschen fehlgeschlagen', 'Bitte versuche es erneut.');
          }
        },
      },
    ]);
  };

  return (
    <ScrollView style={styles.screen} contentContainerStyle={{ padding: spacing.md, paddingBottom: insets.bottom + spacing.xl }}>
      <Section title="Datenschutz">
        <Text style={styles.body}>
          Alle Angaben bleiben ausschließlich auf deinem Gerät, es gibt kein Konto und keine Werbung. Die Kamera wird nur zum
          Scannen von Barcodes genutzt. Beim Scannen und bei der Online-Suche werden der Barcode bzw. dein Suchbegriff und deine
          IP-Adresse an Open Food Facts übermittelt, um das Produkt zu finden.
        </Text>
        <PrimaryButton
          label="Datenschutzerklärung öffnen"
          variant="secondary"
          onPress={() => openLink(LEGAL_URLS.privacyPolicy)}
          style={styles.buttonSpacing}
        />
      </Section>

      <Section title="Impressum">
        <Text style={styles.body}>
          {IMPRINT.name}
          {'\n'}
          {IMPRINT.street}
          {'\n'}
          {IMPRINT.postalCodeAndCity}
          {'\n'}
          {IMPRINT.country}
        </Text>
        <Text style={[styles.body, styles.lineSpacing]}>
          E-Mail: <LinkText label={IMPRINT.email} url={`mailto:${IMPRINT.email}`} />
          {IMPRINT.phone ? `\nTelefon: ${IMPRINT.phone}` : null}
        </Text>
      </Section>

      <Section title="Support">
        <Text style={styles.body}>
          Fragen, Fehler oder Wünsche? Schreib an <LinkText label={IMPRINT.email} url={`mailto:${IMPRINT.email}`} />
        </Text>
      </Section>

      <Section title="Datenquellen">
        <Text style={styles.body}>
          Enthält Produktdaten von <LinkText label="Open Food Facts" url={LEGAL_URLS.openFoodFacts} />, die gemäß der{' '}
          <LinkText label="Open Database License (ODbL)" url={LEGAL_URLS.odbl} /> zur Verfügung gestellt werden.
        </Text>
        <Text style={[styles.body, styles.lineSpacing]}>
          Produktbilder: <LinkText label="Open Food Facts" url={LEGAL_URLS.openFoodFacts} />, lizenziert unter{' '}
          <LinkText label="CC BY-SA" url={LEGAL_URLS.ccBySa} />
        </Text>
      </Section>

      <Section title="Berechnung & Quellen">
        <Text style={styles.body}>So entsteht dein Tagesziel:</Text>
        {CALCULATION_STEPS.map((step, index) => (
          <Text key={step} style={[styles.body, styles.lineSpacing]}>
            {index + 1}. {step}
          </Text>
        ))}
        <Text style={[styles.sourcesLabel, styles.lineSpacing]}>Verwendete Quellen</Text>
        {CALCULATION_SOURCES.map((source) => (
          <View key={source.url} style={styles.source}>
            <Text style={styles.sourceTitle}>{source.title}</Text>
            <Text style={styles.sourceDetail}>{source.detail}</Text>
            <Text style={styles.link} suppressHighlighting onPress={() => openLink(source.url)} accessibilityRole="link">
              Quelle öffnen
            </Text>
          </View>
        ))}
      </Section>

      <Section title="Open-Source-Lizenzen">
        <Text style={styles.body}>
          {APP_NAME} verwendet {licenses.length} Open-Source-Pakete. Die vollständigen Lizenztexte sind in den jeweiligen Paketen
          enthalten.
        </Text>
        <Pressable
          onPress={() => setShowLicenses((v) => !v)}
          style={styles.toggle}
          accessibilityRole="button"
          accessibilityState={{ expanded: showLicenses }}
        >
          <Text style={styles.link}>{showLicenses ? 'Liste ausblenden' : 'Liste anzeigen'}</Text>
          <Icon name={showLicenses ? 'chevronUp' : 'chevronDown'} size={18} color={colors.primary} />
        </Pressable>
        {showLicenses &&
          licenses.map((pkg) => (
            <View key={`${pkg.name}@${pkg.version}`} style={styles.licenseRow}>
              <Text style={styles.licenseName} numberOfLines={1}>
                {pkg.name}
              </Text>
              <Text style={styles.licenseMeta}>
                {pkg.version} · {pkg.license}
              </Text>
            </View>
          ))}
      </Section>

      <Section title="Hinweis">
        <Text style={styles.body}>{MEDICAL_DISCLAIMER}</Text>
      </Section>

      <Section title="Daten">
        <Text style={styles.body}>Löscht dein Profil, alle Einträge und alle gespeicherten Produkte von diesem Gerät.</Text>
        <PrimaryButton
          label="Alle Daten löschen"
          variant="danger"
          onPress={confirmDeleteAll}
          loading={deleting}
          style={styles.buttonSpacing}
        />
      </Section>

      <Text style={styles.version}>
        {APP_NAME} · Version {APP_VERSION}
      </Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  card: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    padding: spacing.md,
    marginBottom: spacing.md,
  },
  sectionTitle: { fontSize: 17, fontWeight: '700', color: colors.text, marginBottom: spacing.sm },
  body: { fontSize: 15, color: colors.text, lineHeight: 22 },
  lineSpacing: { marginTop: spacing.sm },
  link: { color: colors.primary, fontWeight: '600' },
  sourcesLabel: { fontSize: 15, fontWeight: '700', color: colors.text },
  source: { marginTop: spacing.sm },
  sourceTitle: { fontSize: 14, fontWeight: '600', color: colors.text },
  sourceDetail: { fontSize: 13, color: colors.textMuted, lineHeight: 19, marginTop: 2 },
  buttonSpacing: { marginTop: spacing.md },
  toggle: { flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: spacing.sm, alignSelf: 'flex-start', paddingVertical: 4 },
  licenseRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: spacing.sm,
    paddingVertical: 6,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: colors.border,
  },
  licenseName: { flex: 1, fontSize: 13, color: colors.text },
  licenseMeta: { fontSize: 13, color: colors.textMuted, fontVariant: ['tabular-nums'] },
  version: { textAlign: 'center', fontSize: 13, color: colors.textMuted, marginTop: spacing.sm },
});
