import { useRouter } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Chip } from '../components/Chip';
import { LabeledInput } from '../components/LabeledInput';
import { NumericDoneBar } from '../components/NumericDoneBar';
import { PrimaryButton } from '../components/PrimaryButton';
import { getProfile, saveProfile } from '../db/repository';
import { formatInt, parseDecimal, toInputText } from '../lib/format';
import {
  ACTIVITY_LEVELS,
  calculateCalorieGoal,
  DEFAULT_MACRO_SPLIT,
  isValidMacroSplit,
  LIMITS,
  macroGoalsInGrams,
  type ActivityLevel,
  type Sex,
} from '../lib/nutrition';
import { MEDICAL_DISCLAIMER } from '../legal/sources';
import { colors, radius, spacing } from '../theme';

type Range = { min: number; max: number };

function inRange(text: string, range: Range): number | null {
  const value = parseDecimal(text);
  return value !== null && value >= range.min && value <= range.max ? value : null;
}

function rangeError(text: string, range: Range, unit: string): string | null {
  if (text.trim() === '' || inRange(text, range) !== null) return null;
  return `Bitte einen Wert zwischen ${range.min} und ${range.max} ${unit} eingeben.`;
}

const toPercent = (fraction: number) => String(Math.round(fraction * 100));

export default function Onboarding() {
  const db = useSQLiteContext();
  const router = useRouter();
  const insets = useSafeAreaInsets();

  const [age, setAge] = useState('');
  const [sex, setSex] = useState<Sex | null>(null);
  const [height, setHeight] = useState('');
  const [weight, setWeight] = useState('');
  const [goalWeight, setGoalWeight] = useState('');
  const [activity, setActivity] = useState<ActivityLevel | null>(null);
  const [protein, setProtein] = useState(toPercent(DEFAULT_MACRO_SPLIT.protein));
  const [carbs, setCarbs] = useState(toPercent(DEFAULT_MACRO_SPLIT.carbs));
  const [fat, setFat] = useState(toPercent(DEFAULT_MACRO_SPLIT.fat));
  const [saving, setSaving] = useState(false);
  const [hasProfile, setHasProfile] = useState(false);

  // Beim Bearbeiten die gespeicherten Werte vorbefüllen.
  useEffect(() => {
    getProfile(db).then((p) => {
      if (!p) return;
      setHasProfile(true);
      setAge(String(p.age));
      setSex(p.sex);
      setHeight(toInputText(p.heightCm));
      setWeight(toInputText(p.weightKg));
      setGoalWeight(toInputText(p.goalWeightKg));
      setActivity(p.activityLevel);
      setProtein(toPercent(p.macroSplit.protein));
      setCarbs(toPercent(p.macroSplit.carbs));
      setFat(toPercent(p.macroSplit.fat));
    });
  }, [db]);

  const ageValue = inRange(age, LIMITS.age);
  const heightValue = inRange(height, LIMITS.heightCm);
  const weightValue = inRange(weight, LIMITS.weightKg);
  const goalWeightValue = inRange(goalWeight, LIMITS.weightKg);

  const macroSplit = {
    protein: (parseDecimal(protein) ?? NaN) / 100,
    carbs: (parseDecimal(carbs) ?? NaN) / 100,
    fat: (parseDecimal(fat) ?? NaN) / 100,
  };
  const splitValid = isValidMacroSplit(macroSplit);
  const splitSum = [protein, carbs, fat].reduce((sum, t) => sum + (parseDecimal(t) ?? 0), 0);

  const goal =
    ageValue !== null && sex && heightValue !== null && weightValue !== null && goalWeightValue !== null && activity
      ? calculateCalorieGoal({
          age: Math.round(ageValue),
          sex,
          heightCm: heightValue,
          weightKg: weightValue,
          goalWeightKg: goalWeightValue,
          activityLevel: activity,
        })
      : null;

  const canSave = goal !== null && splitValid && !saving;
  const macroGrams = goal && splitValid ? macroGoalsInGrams(goal.dailyGoal, macroSplit) : null;

  const handleSave = async () => {
    if (!goal || !sex || !activity || ageValue === null || heightValue === null || weightValue === null || goalWeightValue === null) return;
    setSaving(true);
    try {
      await saveProfile(db, {
        age: Math.round(ageValue),
        sex,
        heightCm: heightValue,
        weightKg: weightValue,
        goalWeightKg: goalWeightValue,
        activityLevel: activity,
        dailyCalorieGoal: goal.dailyGoal,
        macroSplit,
      });
      if (router.canGoBack()) router.back();
      else router.replace('/');
    } finally {
      setSaving(false);
    }
  };

  const goalHint = goal
    ? goal.adjustment < 0
      ? `Gesamtbedarf ${formatInt(goal.tdee)} kcal, minus ${formatInt(-goal.adjustment)} kcal zum Abnehmen`
      : goal.adjustment > 0
        ? `Gesamtbedarf ${formatInt(goal.tdee)} kcal, plus ${formatInt(goal.adjustment)} kcal zum Zunehmen`
        : `Gesamtbedarf ${formatInt(goal.tdee)} kcal, Gewicht halten`
    : null;

  return (
    <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView
        contentContainerStyle={{ padding: spacing.md, paddingBottom: insets.bottom + spacing.xl }}
        keyboardShouldPersistTaps="handled"
      >
        <Text style={styles.intro}>Einmal ausfüllen. Daraus berechnen wir dein tägliches Kalorienziel.</Text>

        <View style={styles.row}>
          <View style={styles.half}>
            <LabeledInput label="Alter" unit="Jahre" keyboardType="number-pad" value={age} onChangeText={setAge} error={rangeError(age, LIMITS.age, 'Jahren')} />
          </View>
          <View style={styles.half}>
            <LabeledInput label="Größe" unit="cm" value={height} onChangeText={setHeight} error={rangeError(height, LIMITS.heightCm, 'cm')} />
          </View>
        </View>

        <Text style={styles.label}>Geschlecht (für die Formel)</Text>
        <View style={styles.chips}>
          <Chip label="Weiblich" selected={sex === 'female'} onPress={() => setSex('female')} />
          <Chip label="Männlich" selected={sex === 'male'} onPress={() => setSex('male')} />
        </View>

        <View style={styles.row}>
          <View style={styles.half}>
            <LabeledInput label="Aktuelles Gewicht" unit="kg" value={weight} onChangeText={setWeight} error={rangeError(weight, LIMITS.weightKg, 'kg')} />
          </View>
          <View style={styles.half}>
            <LabeledInput label="Zielgewicht" unit="kg" value={goalWeight} onChangeText={setGoalWeight} error={rangeError(goalWeight, LIMITS.weightKg, 'kg')} />
          </View>
        </View>

        <Text style={styles.label}>Aktivität im Alltag</Text>
        {ACTIVITY_LEVELS.map((option) => {
          const selected = activity === option.value;
          return (
            <Pressable
              key={option.value}
              onPress={() => setActivity(option.value)}
              accessibilityRole="radio"
              accessibilityState={{ selected }}
              style={[styles.activity, selected && styles.activitySelected]}
            >
              <Text style={[styles.activityLabel, selected && { color: colors.primary }]}>{option.label}</Text>
              <Text style={styles.activityDescription}>{option.description}</Text>
            </Pressable>
          );
        })}

        <Text style={[styles.label, { marginTop: spacing.md }]}>Makroverteilung</Text>
        <View style={styles.row}>
          <View style={styles.third}>
            <LabeledInput label="Protein" unit="%" keyboardType="number-pad" value={protein} onChangeText={setProtein} />
          </View>
          <View style={styles.third}>
            <LabeledInput label="Kohlenh." unit="%" keyboardType="number-pad" value={carbs} onChangeText={setCarbs} />
          </View>
          <View style={styles.third}>
            <LabeledInput label="Fett" unit="%" keyboardType="number-pad" value={fat} onChangeText={setFat} />
          </View>
        </View>
        {!splitValid && <Text style={styles.error}>Die drei Werte müssen zusammen 100 % ergeben (aktuell {formatInt(splitSum)} %).</Text>}

        <View style={styles.result}>
          <Text style={styles.resultLabel}>Dein Tagesziel</Text>
          <Text style={styles.resultValue}>{goal ? `${formatInt(goal.dailyGoal)} kcal` : '–'}</Text>
          {goal && <Text style={styles.resultHint}>Grundumsatz {formatInt(goal.bmr)} kcal · {goalHint}</Text>}
          {macroGrams && (
            <Text style={styles.resultHint}>
              Protein {macroGrams.protein} g · Kohlenhydrate {macroGrams.carbs} g · Fett {macroGrams.fat} g
            </Text>
          )}
        </View>

        <PrimaryButton label="Speichern" onPress={handleSave} disabled={!canSave} loading={saving} />

        <Text style={styles.note}>
          Alle Angaben bleiben ausschließlich auf deinem Gerät. Es gibt kein Konto und keine Werbung. Beim Scannen und bei der
          Online-Suche wird nur der Barcode bzw. Suchbegriff an Open Food Facts gesendet, um das Produkt zu finden.
        </Text>
        <Text style={styles.note}>
          Berechnet wird der Grundumsatz nach der Formel von Mifflin-St. Jeor, multipliziert mit dem PAL-Faktor deines
          Aktivitätslevels nach den Referenzwerten der Deutschen Gesellschaft für Ernährung.
        </Text>
        <Text style={styles.note}>{MEDICAL_DISCLAIMER}</Text>
        <Pressable onPress={() => router.push('/about')} hitSlop={8} style={styles.aboutLink} accessibilityRole="link">
          <Text style={styles.aboutLinkText}>{hasProfile ? 'Quellen, Info & Rechtliches' : 'Quellen der Berechnung ansehen'}</Text>
        </Pressable>
      </ScrollView>

      <NumericDoneBar />
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  intro: { fontSize: 16, color: colors.textMuted, marginBottom: spacing.md, lineHeight: 22 },
  row: { flexDirection: 'row', gap: spacing.sm },
  half: { flex: 1 },
  third: { flex: 1 },
  label: { fontSize: 14, fontWeight: '600', color: colors.text, marginBottom: 8 },
  chips: { flexDirection: 'row', gap: spacing.sm, marginBottom: spacing.md },
  activity: {
    backgroundColor: colors.surface,
    borderWidth: 1.5,
    borderColor: colors.border,
    borderRadius: radius.md,
    padding: 12,
    marginBottom: 8,
  },
  activitySelected: { borderColor: colors.primary },
  activityLabel: { fontSize: 16, fontWeight: '700', color: colors.text },
  activityDescription: { fontSize: 13, color: colors.textMuted, marginTop: 2 },
  error: { fontSize: 13, color: colors.danger, marginTop: -6, marginBottom: spacing.sm },
  result: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    padding: spacing.md,
    alignItems: 'center',
    marginVertical: spacing.md,
  },
  resultLabel: { fontSize: 14, color: colors.textMuted },
  resultValue: { fontSize: 34, fontWeight: '800', color: colors.text, marginVertical: 4 },
  resultHint: { fontSize: 13, color: colors.textMuted, textAlign: 'center', marginTop: 2 },
  note: { fontSize: 13, color: colors.textMuted, marginTop: spacing.md, lineHeight: 19, textAlign: 'center' },
  aboutLink: { alignSelf: 'center', paddingVertical: spacing.xs, marginTop: spacing.md },
  aboutLinkText: { color: colors.primary, fontSize: 14, fontWeight: '600' },
});
