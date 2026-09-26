import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  bmrMifflinStJeor,
  calculateCalorieGoal,
  chooseDailyGoal,
  CUSTOM_GOAL_LIMITS,
  DEFAULT_MACRO_SPLIT,
  isValidMacroSplit,
  macroGoalsInGrams,
  nutrientsForPortion,
  sumNutrients,
} from '../src/lib/nutrition.ts';

describe('bmrMifflinStJeor', () => {
  it('berechnet den Grundumsatz für Männer', () => {
    // 10*80 + 6.25*180 - 5*30 + 5 = 1780
    assert.equal(bmrMifflinStJeor({ age: 30, sex: 'male', heightCm: 180, weightKg: 80 }), 1780);
  });

  it('berechnet den Grundumsatz für Frauen', () => {
    // 10*65 + 6.25*165 - 5*28 - 161 = 1380.25
    assert.equal(bmrMifflinStJeor({ age: 28, sex: 'female', heightCm: 165, weightKg: 65 }), 1380.25);
  });
});

describe('calculateCalorieGoal', () => {
  const base = { age: 30, sex: 'male' as const, heightCm: 180, weightKg: 80, activityLevel: 'sedentary' as const };

  it('hält das Gewicht ohne Anpassung', () => {
    const goal = calculateCalorieGoal({ ...base, goalWeightKg: 80 });
    assert.equal(goal.bmr, 1780);
    assert.equal(goal.tdee, 2492); // 1780 * 1.4
    assert.equal(goal.adjustment, 0);
    assert.equal(goal.dailyGoal, 2490);
  });

  it('zieht 500 kcal zum Abnehmen ab', () => {
    const goal = calculateCalorieGoal({ ...base, goalWeightKg: 72 });
    assert.equal(goal.adjustment, -500);
    assert.equal(goal.dailyGoal, 1990);
  });

  it('legt 300 kcal zum Zunehmen drauf', () => {
    const goal = calculateCalorieGoal({ ...base, goalWeightKg: 85 });
    assert.equal(goal.dailyGoal, 2790);
  });

  it('ignoriert Abweichungen unter 1 kg', () => {
    assert.equal(calculateCalorieGoal({ ...base, goalWeightKg: 79.5 }).adjustment, 0);
  });

  it('wertet genau 1 kg Unterschied trotz Gleitkomma-Rest als Abnehmen bzw. Zunehmen', () => {
    // 63.1 - 64.1 ergibt -0.9999999999999929 und verfehlte die Schwelle.
    assert.equal(calculateCalorieGoal({ ...base, weightKg: 64.1, goalWeightKg: 63.1 }).adjustment, -500);
    assert.equal(calculateCalorieGoal({ ...base, weightKg: 63.1, goalWeightKg: 64.1 }).adjustment, 300);
  });

  it('geht nie unter den Grundumsatz', () => {
    const goal = calculateCalorieGoal({
      age: 70,
      sex: 'female',
      heightCm: 150,
      weightKg: 45,
      goalWeightKg: 40,
      activityLevel: 'sedentary',
    });
    assert.ok(goal.dailyGoal >= goal.bmr);
  });

  it('bleibt auch nach dem Runden auf 10 kcal über dem Grundumsatz und weist das echte Defizit aus', () => {
    // Grundumsatz 1131,5 → Gesamtbedarf 1584,1. Minus 500 läge darunter, und 1131,5 rundet auf 1130 ab.
    const goal = calculateCalorieGoal({
      age: 55,
      sex: 'female',
      heightCm: 158,
      weightKg: 58,
      goalWeightKg: 52,
      activityLevel: 'sedentary',
    });
    assert.equal(goal.bmr, 1132);
    assert.equal(goal.dailyGoal, 1140);
    assert.equal(goal.adjustment, -453);
  });
});

describe('chooseDailyGoal', () => {
  // Grundumsatz 1780, Tagesziel 1990 (80 → 72 kg)
  const goal = calculateCalorieGoal({ age: 30, sex: 'male', heightCm: 180, weightKg: 80, goalWeightKg: 72, activityLevel: 'sedentary' });

  it('nimmt ohne eigenes Ziel die Berechnung', () => {
    assert.deepEqual(chooseDailyGoal(goal, { enabled: false, kcal: 3000 }), { dailyGoal: 1990, isCustom: false, belowBmr: false });
  });

  it('übernimmt ein eigenes Ziel ganzzahlig', () => {
    assert.deepEqual(chooseDailyGoal(goal, { enabled: true, kcal: 2200.4 }), { dailyGoal: 2200, isCustom: true, belowBmr: false });
  });

  it('erlaubt Ziele unter dem Grundumsatz, markiert sie aber', () => {
    assert.deepEqual(chooseDailyGoal(goal, { enabled: true, kcal: 1500 }), { dailyGoal: 1500, isCustom: true, belowBmr: true });
  });

  it('akzeptiert genau die Grenzen und lehnt alles außerhalb ab', () => {
    assert.equal(chooseDailyGoal(goal, { enabled: true, kcal: CUSTOM_GOAL_LIMITS.min })?.dailyGoal, 1200);
    assert.equal(chooseDailyGoal(goal, { enabled: true, kcal: CUSTOM_GOAL_LIMITS.max })?.dailyGoal, 5000);
    assert.equal(chooseDailyGoal(goal, { enabled: true, kcal: 1199 }), null);
    assert.equal(chooseDailyGoal(goal, { enabled: true, kcal: 5001 }), null);
    assert.equal(chooseDailyGoal(goal, { enabled: true, kcal: null }), null);
  });
});

describe('Makros', () => {
  it('rechnet die Standardverteilung in Gramm um', () => {
    // 2000 kcal: 30 % Protein = 150 g, 50 % KH = 250 g, 20 % Fett = 44 g
    assert.deepEqual(macroGoalsInGrams(2000, DEFAULT_MACRO_SPLIT), { protein: 150, carbs: 250, fat: 44 });
  });

  it('prüft, dass die Verteilung 100 % ergibt', () => {
    assert.equal(isValidMacroSplit(DEFAULT_MACRO_SPLIT), true);
    assert.equal(isValidMacroSplit({ protein: 0.4, carbs: 0.4, fat: 0.1 }), false);
    assert.equal(isValidMacroSplit({ protein: NaN, carbs: 0.8, fat: 0.2 }), false);
  });
});

describe('Portionen', () => {
  const quark = { calories: 67, protein: 12, carbs: 4.2, fat: 0.2 };

  it('rechnet auf die gegessene Menge um', () => {
    assert.deepEqual(nutrientsForPortion(quark, 250), { calories: 168, protein: 30, carbs: 10.5, fat: 0.5 });
  });

  it('summiert ohne Gleitkomma-Reste', () => {
    const total = sumNutrients([
      { calories: 10, protein: 0.1, carbs: 0.2, fat: 0.1 },
      { calories: 20, protein: 0.2, carbs: 0.1, fat: 0.2 },
    ]);
    assert.deepEqual(total, { calories: 30, protein: 0.3, carbs: 0.3, fat: 0.3 });
  });
});
