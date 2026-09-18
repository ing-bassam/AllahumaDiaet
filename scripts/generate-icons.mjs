// Erzeugt alle App-Icons und das Startbild aus den Markendateien in assets/source/ und prüft das Ergebnis.
// Aufruf: npm run icons
//
// Quellen:
//   assets/source/icon.png     – quadratisches „H.“-Zeichen auf cremefarbenem Grund
//   assets/source/wordmark.png – Schriftzug „Hachibu.“ auf transparentem Grund

import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import sharp from 'sharp';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const assetsDir = path.join(root, 'assets');
const sourceIcon = path.join(assetsDir, 'source', 'icon.png');
const sourceWordmark = path.join(assetsDir, 'source', 'wordmark.png');

/** Markenfarben, aus den Vorlagen gelesen. */
export const BRAND_BACKGROUND = '#F7F6F3';
/** Abstand im Farbraum, bis zu dem ein Pixel noch als Hintergrund gilt. */
const BACKGROUND_TOLERANCE = 24;

// Android: Das adaptive Icon ist 108 dp groß, sichtbar ist garantiert nur ein Kreis mit 66 dp Durchmesser.
const ADAPTIVE_SAFE_ZONE = 66 / 108;

const TRANSPARENT = { r: 0, g: 0, b: 0, alpha: 0 };

const hexToRgb = (hex) => ({
  r: parseInt(hex.slice(1, 3), 16),
  g: parseInt(hex.slice(3, 5), 16),
  b: parseInt(hex.slice(5, 7), 16),
});

/** Schneidet den cremefarbenen Hintergrund aus dem Zeichen heraus und beschneidet auf den Inhalt. */
async function extractMark() {
  const { data, info } = await sharp(sourceIcon).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const bg = hexToRgb(BRAND_BACKGROUND);

  for (let i = 0; i < data.length; i += 4) {
    const dr = data[i] - bg.r;
    const dg = data[i + 1] - bg.g;
    const db = data[i + 2] - bg.b;
    if (dr * dr + dg * dg + db * db <= BACKGROUND_TOLERANCE * BACKGROUND_TOLERANCE) data[i + 3] = 0;
  }

  const withAlpha = await sharp(data, { raw: { width: info.width, height: info.height, channels: 4 } })
    .png()
    .toBuffer();
  return sharp(withAlpha).trim().png().toBuffer();
}

/** Legt ein Bild mittig auf eine quadratische Fläche; `scale` ist der Anteil der Kantenlänge. */
async function centered(input, size, scale, background = TRANSPARENT) {
  const inner = Math.round(size * scale);
  const resized = await sharp(input).resize(inner, inner, { fit: 'contain', background: TRANSPARENT }).toBuffer();
  return sharp({ create: { width: size, height: size, channels: 4, background } })
    .composite([{ input: resized, gravity: 'center' }])
    .png({ compressionLevel: 9 })
    .toBuffer();
}

/** Ersetzt alle Farben durch Weiß und behält nur die Form; Android nutzt davon nur den Alphakanal. */
async function toSilhouette(input) {
  const { data, info } = await sharp(input).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  for (let i = 0; i < data.length; i += 4) {
    data[i] = 255;
    data[i + 1] = 255;
    data[i + 2] = 255;
  }
  return sharp(data, { raw: { width: info.width, height: info.height, channels: 4 } })
    .png({ compressionLevel: 9 })
    .toBuffer();
}

const mark = await extractMark();
const wordmark = await readFile(sourceWordmark);

// Motiv im adaptiven Icon: 40 % Kantenlänge, damit auch die Diagonale in der Safe Zone bleibt.
const adaptiveScale = 0.4;

const outputs = [
  {
    file: 'icon.png',
    size: 1024,
    // App Store: 1024 px ohne Alphakanal. Die Vorlage bringt den Rand schon mit.
    buffer: () => sharp(sourceIcon).resize(1024, 1024, { fit: 'contain', background: BRAND_BACKGROUND }).flatten({ background: BRAND_BACKGROUND }).removeAlpha().png({ compressionLevel: 9 }).toBuffer(),
    opaque: true,
  },
  {
    // Startbild: Schriftzug auf transparentem Grund, die Farbe kommt aus dem Splash-Plugin.
    file: 'splash-icon.png',
    width: 1200,
    height: 400,
    buffer: () => sharp(wordmark).resize(1200, 400, { fit: 'contain', background: TRANSPARENT }).png({ compressionLevel: 9 }).toBuffer(),
    opaque: false,
  },
  {
    file: 'android-icon-foreground.png',
    size: 512,
    buffer: () => centered(mark, 512, adaptiveScale),
    opaque: false,
    safeZone: true,
  },
  {
    file: 'android-icon-background.png',
    size: 512,
    buffer: () =>
      sharp({ create: { width: 512, height: 512, channels: 3, background: BRAND_BACKGROUND } })
        .png({ compressionLevel: 9 })
        .toBuffer(),
    opaque: true,
  },
  {
    // Android 13+ „Designfarben“-Icon: Das System nutzt nur den Alphakanal.
    file: 'android-icon-monochrome.png',
    size: 432,
    buffer: async () => toSilhouette(await centered(mark, 432, adaptiveScale)),
    opaque: false,
    safeZone: true,
  },
  {
    file: 'favicon.png',
    size: 48,
    buffer: () => sharp(sourceIcon).resize(48, 48).flatten({ background: BRAND_BACKGROUND }).removeAlpha().png({ compressionLevel: 9 }).toBuffer(),
    opaque: true,
  },
];

for (const out of outputs) {
  const buffer = await out.buffer();
  await sharp(buffer).toFile(path.join(assetsDir, out.file));
}

// Prüfung
const rows = [];
let failed = false;

for (const out of outputs) {
  const file = path.join(assetsDir, out.file);
  const meta = await sharp(file).metadata();
  const expectedWidth = out.width ?? out.size;
  const expectedHeight = out.height ?? out.size;
  const problems = [];

  if (meta.width !== expectedWidth || meta.height !== expectedHeight) {
    problems.push(`Größe ${meta.width}×${meta.height} statt ${expectedWidth}×${expectedHeight}`);
  }
  if (out.opaque && meta.hasAlpha) problems.push('hat Alphakanal');
  if (!out.opaque && !meta.hasAlpha) problems.push('kein Alphakanal');

  let safeZone = '';
  if (out.safeZone) {
    const { data, info } = await sharp(file).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    const center = (info.width - 1) / 2;
    let maxDistance = 0;
    for (let y = 0; y < info.height; y++) {
      for (let x = 0; x < info.width; x++) {
        if (data[(y * info.width + x) * 4 + 3] > 0) {
          maxDistance = Math.max(maxDistance, Math.hypot(x - center, y - center));
        }
      }
    }
    const allowed = (info.width * ADAPTIVE_SAFE_ZONE) / 2;
    safeZone = `${Math.round(maxDistance)}/${Math.round(allowed)} px`;
    if (maxDistance > allowed) problems.push('Motiv ragt aus der Safe Zone');
  }

  if (problems.length) failed = true;
  rows.push({
    Datei: out.file,
    Größe: `${meta.width}×${meta.height}`,
    Farbraum: meta.space,
    Kanäle: meta.channels,
    Alpha: meta.hasAlpha ? 'ja' : 'nein',
    'Safe Zone (max/erlaubt)': safeZone || '–',
    Ergebnis: problems.length ? problems.join(', ') : 'OK',
  });
}

console.table(rows);
if (failed) {
  console.error('Mindestens ein Icon entspricht nicht den Vorgaben.');
  process.exit(1);
}
