// „Wie gestern“: Mahlzeiten des Vortags, die am gewählten Tag noch fehlen, mit einem Tipp übernehmen.

import { MEAL_TYPES, type MealType } from './format.ts';

export type MealToRepeat<T> = { mealType: MealType; label: string; entries: T[] };

/**
 * Mahlzeiten, die am Vortag Einträge hatten und am gewählten Tag noch leer sind, in der Reihenfolge
 * des Tages. Eine Mahlzeit mit schon vorhandenen Einträgen wird nicht angeboten, damit nichts doppelt
 * im Tagebuch landet.
 */
export function mealsToRepeat<T extends { mealType: MealType }>(previousDay: T[], selectedDay: T[]): MealToRepeat<T>[] {
  const taken = new Set(selectedDay.map((e) => e.mealType));
  return MEAL_TYPES.flatMap(({ value, label }) => {
    if (taken.has(value)) return [];
    const entries = previousDay.filter((e) => e.mealType === value);
    return entries.length > 0 ? [{ mealType: value, label, entries }] : [];
  });
}
