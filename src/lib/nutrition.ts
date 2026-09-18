// Reine Rechenlogik ohne React-Native-Abhängigkeiten, damit sie mit `node --test` testbar bleibt.

export type Sex = 'male' | 'female';
export type ActivityLevel = 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active';

export type ActivityOption = {
  value: ActivityLevel;
  label: string;
  description: string;
  pal: number;
};

// PAL-Werte angelehnt an die Referenzwerte der DGE.
export const ACTIVITY_LEVELS: ActivityOption[] = [
  { value: 'sedentary', label: 'Sitzend', description: 'Bürojob, kaum Bewegung', pal: 1.4 },
  { value: 'light', label: 'Leicht aktiv', description: 'Sitzend, zeitweise gehend oder stehend', pal: 1.6 },
  { value: 'moderate', label: 'Aktiv', description: 'Überwiegend gehend oder stehend', pal: 1.8 },
  { value: 'active', label: 'Sehr aktiv', description: 'Körperlich anstrengender Beruf oder viel Sport', pal: 2.0 },
  { value: 'very_active', label: 'Schwerstarbeit', description: 'z. B. Bau, Landwirtschaft, Leistungssport', pal: 2.3 },
];

export type MacroSplit = { protein: number; carbs: number; fat: number };

export const DEFAULT_MACRO_SPLIT: MacroSplit = { protein: 0.3, carbs: 0.5, fat: 0.2 };

export const KCAL_PER_GRAM = { protein: 4, carbs: 4, fat: 9 } as const;

// Tagesdefizit bzw. -überschuss, wenn das Zielgewicht vom aktuellen Gewicht abweicht.
export const LOSE_WEIGHT_ADJUSTMENT = -500;
export const GAIN_WEIGHT_ADJUSTMENT = 300;

export type BodyData = {
  age: number;
  sex: Sex;
  heightCm: number;
  weightKg: number;
};

export type GoalInput = BodyData & {
  goalWeightKg: number;
  activityLevel: ActivityLevel;
};

export type CalorieGoal = {
  bmr: number;
  tdee: number;
  adjustment: number;
  dailyGoal: number;
};

export const LIMITS = {
  age: { min: 18, max: 100 },
  heightCm: { min: 120, max: 230 },
  weightKg: { min: 30, max: 300 },
} as const;

/** Grundumsatz nach Mifflin-St. Jeor in kcal/Tag. */
export function bmrMifflinStJeor({ age, sex, heightCm, weightKg }: BodyData): number {
  const base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return sex === 'male' ? base + 5 : base - 161;
}

export function palFor(level: ActivityLevel): number {
  const option = ACTIVITY_LEVELS.find((o) => o.value === level);
  if (!option) throw new Error(`Unbekanntes Aktivitätslevel: ${level}`);
  return option.pal;
}

export function calculateCalorieGoal(input: GoalInput): CalorieGoal {
  const bmr = bmrMifflinStJeor(input);
  const tdee = bmr * palFor(input.activityLevel);
  const weightDiff = input.goalWeightKg - input.weightKg;

  let adjustment = 0;
  if (weightDiff <= -1) adjustment = LOSE_WEIGHT_ADJUSTMENT;
  else if (weightDiff >= 1) adjustment = GAIN_WEIGHT_ADJUSTMENT;

  const target = tdee + adjustment;
  // Nie unter den Grundumsatz gehen – auch nicht durch das Runden auf 10 kcal. Die Untergrenze ist
  // deshalb der auf 10 kcal aufgerundete angezeigte Grundumsatz.
  const dailyGoal = Math.max(roundTo(target, 10), Math.ceil(Math.round(bmr) / 10) * 10);
  // Greift die Untergrenze, das tatsächliche Defizit ausweisen statt der nominellen 500 kcal.
  const effectiveAdjustment = target < bmr ? Math.round(bmr - tdee) : adjustment;
  return { bmr: Math.round(bmr), tdee: Math.round(tdee), adjustment: effectiveAdjustment, dailyGoal };
}

export function macroGoalsInGrams(dailyCalories: number, split: MacroSplit): MacroSplit {
  return {
    protein: Math.round((dailyCalories * split.protein) / KCAL_PER_GRAM.protein),
    carbs: Math.round((dailyCalories * split.carbs) / KCAL_PER_GRAM.carbs),
    fat: Math.round((dailyCalories * split.fat) / KCAL_PER_GRAM.fat),
  };
}

export function isValidMacroSplit(split: MacroSplit): boolean {
  const parts = [split.protein, split.carbs, split.fat];
  if (parts.some((p) => !Number.isFinite(p) || p < 0 || p > 1)) return false;
  return Math.round((split.protein + split.carbs + split.fat) * 100) === 100;
}

export type Nutrients = { calories: number; protein: number; carbs: number; fat: number };

/** Rechnet Nährwerte pro 100 g auf die gegessene Menge um. */
export function nutrientsForPortion(per100g: Nutrients, grams: number): Nutrients {
  const factor = grams / 100;
  return {
    calories: Math.round(per100g.calories * factor),
    protein: roundTo(per100g.protein * factor, 0.1),
    carbs: roundTo(per100g.carbs * factor, 0.1),
    fat: roundTo(per100g.fat * factor, 0.1),
  };
}

/**
 * Gegenstück zu `nutrientsForPortion`: rechnet Nährwerte einer Portion auf 100 g hoch.
 * Bewusst fein gerundet, damit dieselbe Portion anschließend wieder exakt dieselben Werte ergibt.
 */
export function portionToPer100g(portion: Nutrients, grams: number): Nutrients {
  if (!Number.isFinite(grams) || grams <= 0) throw new RangeError('Die Portion muss mehr als 0 g haben.');
  const factor = 100 / grams;
  return {
    calories: roundTo(portion.calories * factor, 0.0001),
    protein: roundTo(portion.protein * factor, 0.0001),
    carbs: roundTo(portion.carbs * factor, 0.0001),
    fat: roundTo(portion.fat * factor, 0.0001),
  };
}

export const MAX_KCAL_PER_100G = 900;
export const MAX_MACROS_PER_100G = 100;

export type NutrientValidation = {
  calories: string | null;
  protein: string | null;
  carbs: string | null;
  fat: string | null;
  /** Fehler, der die Summe der Makros betrifft. */
  macroTotal: string | null;
  valid: boolean;
};

/** Harte Regeln für Nährwerte pro 100 g. Verstöße verhindern das Speichern. */
export function validateNutrients(per100g: Nutrients): NutrientValidation {
  const negative = (value: number) => (!Number.isFinite(value) || value < 0 ? 'Bitte einen Wert ab 0 eingeben.' : null);

  const calories =
    negative(per100g.calories) ??
    (per100g.calories > MAX_KCAL_PER_100G ? `Mehr als ${MAX_KCAL_PER_100G} kcal pro 100 g ist nicht möglich.` : null);
  const protein = negative(per100g.protein);
  const carbs = negative(per100g.carbs);
  const fat = negative(per100g.fat);

  const macroSum = per100g.protein + per100g.carbs + per100g.fat;
  const macroTotal =
    !protein && !carbs && !fat && macroSum > MAX_MACROS_PER_100G
      ? `Protein, Kohlenhydrate und Fett zusammen können nicht über ${MAX_MACROS_PER_100G} g pro 100 g liegen.`
      : null;

  return { calories, protein, carbs, fat, macroTotal, valid: !calories && !protein && !carbs && !fat && !macroTotal };
}

/**
 * Ab dieser relativen Abweichung zwischen angegebenen kcal und 4·P + 4·K + 9·F wird gewarnt.
 * Die Formel ist nur eine Näherung: Ballaststoffe (ca. 2 kcal/g, auf EU-Etiketten nicht in den
 * Kohlenhydraten enthalten), Alkohol (7 kcal/g) und Zuckeralkohole bringen Energie ohne Makro-Anteil.
 * Deshalb nur ein Hinweis, kein Fehler.
 */
export const PLAUSIBILITY_TOLERANCE = 0.2;
/** Kleine absolute Abweichungen (z. B. Tee mit 1 kcal) sind kein Grund für eine Warnung. */
export const PLAUSIBILITY_MIN_DIFF_KCAL = 15;

export function plausibilityWarning(per100g: Nutrients): string | null {
  if (!validateNutrients(per100g).valid) return null;
  const expected = KCAL_PER_GRAM.protein * per100g.protein + KCAL_PER_GRAM.carbs * per100g.carbs + KCAL_PER_GRAM.fat * per100g.fat;
  const diff = Math.abs(per100g.calories - expected);
  if (diff < PLAUSIBILITY_MIN_DIFF_KCAL) return null;
  if (expected > 0 && diff / expected <= PLAUSIBILITY_TOLERANCE) return null;
  return `Die Kalorien passen nicht ganz zu den Makros (daraus ergeben sich etwa ${Math.round(expected)} kcal). Bitte prüfen.`;
}

export function sumNutrients(items: Nutrients[]): Nutrients {
  const total = items.reduce(
    (acc, n) => ({
      calories: acc.calories + n.calories,
      protein: acc.protein + n.protein,
      carbs: acc.carbs + n.carbs,
      fat: acc.fat + n.fat,
    }),
    { calories: 0, protein: 0, carbs: 0, fat: 0 },
  );
  return {
    calories: Math.round(total.calories),
    protein: roundTo(total.protein, 0.1),
    carbs: roundTo(total.carbs, 0.1),
    fat: roundTo(total.fat, 0.1),
  };
}

export function roundTo(value: number, step: number): number {
  const rounded = Math.round(value / step) * step;
  // Gleitkomma-Reste wie 12.300000000000001 entfernen.
  return Number(rounded.toFixed(step < 1 ? String(step).split('.')[1].length : 0));
}
