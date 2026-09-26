import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import type { MealType } from '../src/lib/format.ts';
import { mealsToRepeat } from '../src/lib/repeatMeals.ts';

const entry = (id: string, mealType: MealType) => ({ id, mealType });

describe('mealsToRepeat', () => {
  it('bietet die Mahlzeiten des Vortags in der Reihenfolge des Tages an', () => {
    const yesterday = [entry('s1', 'snack'), entry('b1', 'breakfast'), entry('b2', 'breakfast'), entry('d1', 'dinner')];
    const result = mealsToRepeat(yesterday, []);
    assert.deepEqual(
      result.map((m) => [m.mealType, m.label, m.entries.map((e) => e.id)]),
      [
        ['breakfast', 'Frühstück', ['b1', 'b2']],
        ['dinner', 'Abendessen', ['d1']],
        ['snack', 'Snacks', ['s1']],
      ],
    );
  });

  it('lässt Mahlzeiten weg, die heute schon Einträge haben', () => {
    const yesterday = [entry('b1', 'breakfast'), entry('l1', 'lunch')];
    const today = [entry('b9', 'breakfast')];
    assert.deepEqual(
      mealsToRepeat(yesterday, today).map((m) => m.mealType),
      ['lunch'],
    );
  });

  it('bietet nichts an, wenn der Vortag leer ist', () => {
    assert.deepEqual(mealsToRepeat([], [entry('b1', 'breakfast')]), []);
  });
});
