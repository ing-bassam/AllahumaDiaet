// Eingabezustand der Nährwertfelder. Die Felder zeigen Werte „pro 100 g“ oder „pro Portion“,
// gespeichert wird immer pro 100 g. Umgerechnet wird ausschließlich über nutrition.ts.

import { parseDecimal, toInputText } from './format.ts';
import { nutrientsForPortion, portionToPer100g, type Nutrients } from './nutrition.ts';

export type NutritionMode = 'per100g' | 'portion';

export type NutrientDraft = { calories: string; protein: string; carbs: string; fat: string };

export const EMPTY_DRAFT: NutrientDraft = { calories: '', protein: '', carbs: '', fat: '' };

export function isUsablePortion(grams: number | null | undefined): grams is number {
  return typeof grams === 'number' && Number.isFinite(grams) && grams > 0;
}

/** Werte für die Felder im gewünschten Modus. Portionen werden wie in der Anzeige gerundet. */
export function draftFromPer100g(per100g: Nutrients, mode: NutritionMode, grams: number | null): NutrientDraft {
  const shown = mode === 'portion' && isUsablePortion(grams) ? nutrientsForPortion(per100g, grams) : per100g;
  return {
    calories: toInputText(shown.calories),
    protein: toInputText(shown.protein),
    carbs: toInputText(shown.carbs),
    fat: toInputText(shown.fat),
  };
}

/** Liest die Felder; `null`, solange ein Feld leer oder keine Zahl ist. */
export function parseDraft(draft: NutrientDraft): Nutrients | null {
  const calories = parseDecimal(draft.calories);
  const protein = parseDecimal(draft.protein);
  const carbs = parseDecimal(draft.carbs);
  const fat = parseDecimal(draft.fat);
  if (calories === null || protein === null || carbs === null || fat === null) return null;
  return { calories, protein, carbs, fat };
}

/**
 * Übernimmt nur die vom Nutzer bearbeiteten Felder aus den Feldwerten; alle übrigen behalten ihren
 * gespeicherten Wert. Die Felder zeigen gerundete Zahlen – pro Portion etwa „0,1“ für 0,06 g –, und
 * zurückgerechnet würden sie Werte verfälschen, die der Nutzer nie angefasst hat.
 */
export function mergeEditedFields(
  base: Nutrients | null,
  parsed: Nutrients,
  edited: ReadonlySet<keyof NutrientDraft>,
): Nutrients {
  if (!base) return parsed;
  const merged = { ...base };
  for (const field of edited) merged[field] = parsed[field];
  return merged;
}

/** Rechnet die Feldwerte auf 100 g um; `null` bei unvollständigen Feldern oder fehlender Portionsgröße. */
export function draftToPer100g(draft: NutrientDraft, mode: NutritionMode, grams: number | null): Nutrients | null {
  const values = parseDraft(draft);
  if (!values) return null;
  if (mode === 'per100g') return values;
  return isUsablePortion(grams) ? portionToPer100g(values, grams) : null;
}
