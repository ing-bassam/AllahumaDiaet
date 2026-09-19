import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  MAX_KCAL_PER_100G,
  nutrientsForPortion,
  plausibilityWarning,
  portionToPer100g,
  validateNutrients,
} from '../src/lib/nutrition.ts';

describe('portionToPer100g', () => {
  it('rechnet eine Portion auf 100 g hoch', () => {
    assert.deepEqual(portionToPer100g({ calories: 50, protein: 5, carbs: 2.5, fat: 1 }, 50), {
      calories: 100,
      protein: 10,
      carbs: 5,
      fat: 2,
    });
  });

  it('ergibt über nutrientsForPortion wieder dieselbe Portion', () => {
    const portion = { calories: 50, protein: 3.2, carbs: 6.1, fat: 1.4 };
    for (const grams of [37, 12.5, 250, 3]) {
      assert.deepEqual(nutrientsForPortion(portionToPer100g(portion, grams), grams), portion, `bei ${grams} g`);
    }
  });

  it('lehnt 0 g und ungültige Mengen ab', () => {
    assert.throws(() => portionToPer100g({ calories: 1, protein: 0, carbs: 0, fat: 0 }, 0), RangeError);
    assert.throws(() => portionToPer100g({ calories: 1, protein: 0, carbs: 0, fat: 0 }, Number.NaN), RangeError);
  });
});

describe('validateNutrients', () => {
  it('akzeptiert normale Werte', () => {
    assert.equal(validateNutrients({ calories: 67, protein: 12, carbs: 4, fat: 0.2 }).valid, true);
  });

  it('meldet mehr als 900 kcal', () => {
    const result = validateNutrients({ calories: MAX_KCAL_PER_100G + 1, protein: 0, carbs: 0, fat: 100 });
    assert.equal(result.valid, false);
    assert.match(result.calories ?? '', /900 kcal/);
  });

  it('meldet Makros über 100 g zusammen', () => {
    const result = validateNutrients({ calories: 400, protein: 40, carbs: 50, fat: 20 });
    assert.equal(result.valid, false);
    assert.ok(result.macroTotal);
  });

  it('akzeptiert Makros, die zusammen genau 100 g ergeben', () => {
    // 85.2 + 7.4 + 7.4 ergibt in Gleitkomma 100.00000000000001.
    assert.equal(validateNutrients({ calories: 420, protein: 85.2, carbs: 7.4, fat: 7.4 }).valid, true);
    // 20/5/5 g in einer 30-g-Portion: auf 100 g umgerechnet 66.6667 + 16.6667 + 16.6667 = 100.0001.
    assert.equal(validateNutrients(portionToPer100g({ calories: 120, protein: 20, carbs: 5, fat: 5 }, 30)).valid, true);
  });

  it('meldet negative Werte am jeweiligen Feld', () => {
    const result = validateNutrients({ calories: 100, protein: -1, carbs: 10, fat: 1 });
    assert.equal(result.valid, false);
    assert.ok(result.protein);
    assert.equal(result.carbs, null);
    assert.equal(result.macroTotal, null);
  });
});

describe('plausibilityWarning', () => {
  it('schweigt, wenn kcal zu den Makros passen', () => {
    // 4·12 + 4·4 + 9·0.2 = 65.8
    assert.equal(plausibilityWarning({ calories: 67, protein: 12, carbs: 4, fat: 0.2 }), null);
  });

  it('warnt bei deutlicher Abweichung', () => {
    // erwartet 4·10 + 4·50 + 9·10 = 330
    assert.match(plausibilityWarning({ calories: 150, protein: 10, carbs: 50, fat: 10 }) ?? '', /330 kcal/);
  });

  it('toleriert bis 20 % Abweichung', () => {
    // erwartet 330, 20 % = 66 → 390 ist noch in Ordnung, 400 nicht
    assert.equal(plausibilityWarning({ calories: 390, protein: 10, carbs: 50, fat: 10 }), null);
    assert.notEqual(plausibilityWarning({ calories: 400, protein: 10, carbs: 50, fat: 10 }), null);
  });

  it('ignoriert kleine absolute Unterschiede bei sehr kalorienarmen Lebensmitteln', () => {
    assert.equal(plausibilityWarning({ calories: 2, protein: 0.1, carbs: 0, fat: 0 }), null);
  });

  it('gibt bei ungültigen Werten keine zusätzliche Warnung', () => {
    assert.equal(plausibilityWarning({ calories: 1000, protein: 0, carbs: 0, fat: 0 }), null);
  });
});
