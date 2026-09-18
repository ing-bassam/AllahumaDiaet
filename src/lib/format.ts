// Zahlen- und Datumsformatierung für die deutsche Oberfläche.

export type MealType = 'breakfast' | 'lunch' | 'dinner' | 'snack';

export const MEAL_TYPES: { value: MealType; label: string }[] = [
  { value: 'breakfast', label: 'Frühstück' },
  { value: 'lunch', label: 'Mittagessen' },
  { value: 'dinner', label: 'Abendessen' },
  { value: 'snack', label: 'Snacks' },
];

/** Schlägt die Mahlzeit anhand der Uhrzeit vor. */
export function defaultMealType(date: Date): MealType {
  const hour = date.getHours();
  if (hour >= 4 && hour < 11) return 'breakfast';
  if (hour >= 11 && hour < 15) return 'lunch';
  if (hour >= 17 && hour < 22) return 'dinner';
  return 'snack';
}

/** Lokales Datum als YYYY-MM-DD (nicht UTC, sonst landet ein Eintrag um 0:30 Uhr am Vortag). */
export function localDateKey(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function formatTime(isoTimestamp: string): string {
  const date = new Date(isoTimestamp);
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

/** Ganze Zahl mit Tausenderpunkt, z. B. 2.150 */
export function formatInt(value: number): string {
  return String(Math.round(value)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

/** Höchstens eine Nachkommastelle mit Komma, z. B. 12,5 oder 12 */
export function formatDecimal(value: number): string {
  const rounded = Math.round(value * 10) / 10;
  return Number.isInteger(rounded) ? formatInt(rounded) : rounded.toFixed(1).replace('.', ',');
}

/** Zahl als Text für ein Eingabefeld: Komma statt Punkt, ohne Tausenderpunkt (sonst liest `parseDecimal` 1.000 als 1). */
export function toInputText(value: number): string {
  return String(Math.round(value * 10) / 10).replace('.', ',');
}

/** Liest Nutzereingaben mit Komma oder Punkt; leer oder ungültig ergibt `null`. */
export function parseDecimal(text: string): number | null {
  const normalized = text.trim().replace(',', '.');
  if (normalized === '' || !/^\d*\.?\d*$/.test(normalized) || normalized === '.') return null;
  const value = Number(normalized);
  return Number.isFinite(value) ? value : null;
}
