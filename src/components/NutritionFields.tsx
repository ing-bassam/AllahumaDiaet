import { useEffect, useRef, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { formatDecimal } from '../lib/format';
import { plausibilityWarning, validateNutrients, type Nutrients, type NutrientValidation } from '../lib/nutrition';
import {
  draftFromPer100g,
  draftToPer100g,
  EMPTY_DRAFT,
  isUsablePortion,
  type NutrientDraft,
  type NutritionMode,
} from '../lib/nutritionDraft';
import { colors, spacing } from '../theme';
import { Chip } from './Chip';
import { LabeledInput } from './LabeledInput';

export type NutritionEditor = {
  mode: NutritionMode;
  setMode: (mode: NutritionMode) => void;
  draft: NutrientDraft;
  setField: (field: keyof NutrientDraft, text: string) => void;
  portionGrams: number | null;
  portionLabel: string;
  /** Pro 100 g, sobald alle Felder ausgefüllt sind. Ohne Änderung exakt die Ausgangswerte. */
  per100g: Nutrients | null;
  validation: NutrientValidation | null;
  warning: string | null;
  /** Vollständig und gültig. */
  isValid: boolean;
  /** Der Nutzer hat mindestens ein Feld geändert. */
  touched: boolean;
};

type Options = {
  initialPer100g: Nutrients | null;
  /** Grammzahl für den Modus „pro Portion“; ohne gültige Menge ist der Modus nicht wählbar. */
  portionGrams: number | null;
  initialMode?: NutritionMode;
  /** Beschriftung des Portionsmodus, z. B. „pro Portion“ oder „pro Packung“. */
  portionLabel?: string;
};

export function useNutritionEditor({ initialPer100g, portionGrams, initialMode = 'per100g', portionLabel = 'pro Portion' }: Options): NutritionEditor {
  const startMode = initialMode === 'portion' && isUsablePortion(portionGrams) ? 'portion' : 'per100g';
  const [mode, setModeState] = useState<NutritionMode>(startMode);
  const [draft, setDraft] = useState<NutrientDraft>(() =>
    initialPer100g ? draftFromPer100g(initialPer100g, startMode, portionGrams) : EMPTY_DRAFT,
  );
  // Kanonischer Wert pro 100 g. Bleibt unverändert, solange der Nutzer nichts eintippt,
  // damit gerundete Anzeigewerte die gespeicherten Werte nicht verfälschen.
  const [per100g, setPer100g] = useState<Nutrients | null>(initialPer100g);
  const [touched, setTouched] = useState(false);

  const setField = (field: keyof NutrientDraft, text: string) => {
    const next = { ...draft, [field]: text };
    setDraft(next);
    setTouched(true);
    setPer100g(draftToPer100g(next, mode, portionGrams));
  };

  const setMode = (nextMode: NutritionMode) => {
    if (nextMode === mode || (nextMode === 'portion' && !isUsablePortion(portionGrams))) return;
    setModeState(nextMode);
    if (per100g) setDraft(draftFromPer100g(per100g, nextMode, portionGrams));
  };

  // Ändert sich die Menge, rechnen die Portionsfelder proportional über die Werte pro 100 g mit.
  const lastGrams = useRef(portionGrams);
  useEffect(() => {
    if (lastGrams.current === portionGrams) return;
    lastGrams.current = portionGrams;
    if (mode !== 'portion') return;
    if (!isUsablePortion(portionGrams)) {
      setModeState('per100g');
      if (per100g) setDraft(draftFromPer100g(per100g, 'per100g', null));
      return;
    }
    if (per100g) setDraft(draftFromPer100g(per100g, 'portion', portionGrams));
  }, [portionGrams, mode, per100g]);

  const validation = per100g ? validateNutrients(per100g) : null;
  return {
    mode,
    setMode,
    draft,
    setField,
    portionGrams,
    portionLabel,
    per100g,
    validation,
    warning: per100g ? plausibilityWarning(per100g) : null,
    isValid: validation?.valid ?? false,
    touched,
  };
}

type Props = { editor: NutritionEditor; autoFocus?: boolean };

export function NutritionFields({ editor, autoFocus = false }: Props) {
  const { mode, setMode, draft, setField, portionGrams, portionLabel, validation, warning } = editor;

  return (
    <View>
      <View style={styles.modes}>
        <Chip label="pro 100 g" selected={mode === 'per100g'} onPress={() => setMode('per100g')} />
        {isUsablePortion(portionGrams) && (
          <Chip
            label={`${portionLabel} (${formatDecimal(portionGrams)} g)`}
            selected={mode === 'portion'}
            onPress={() => setMode('portion')}
          />
        )}
      </View>

      <LabeledInput
        label="Kalorien"
        unit="kcal"
        value={draft.calories}
        onChangeText={(t) => setField('calories', t)}
        error={validation?.calories}
        autoFocus={autoFocus}
      />
      <View style={styles.macroRow}>
        <View style={styles.macro}>
          <LabeledInput
            label="Protein"
            unit="g"
            value={draft.protein}
            onChangeText={(t) => setField('protein', t)}
            error={validation?.protein}
          />
        </View>
        <View style={styles.macro}>
          <LabeledInput
            label="Kohlenh."
            unit="g"
            value={draft.carbs}
            onChangeText={(t) => setField('carbs', t)}
            error={validation?.carbs}
          />
        </View>
        <View style={styles.macro}>
          <LabeledInput
            label="Fett"
            unit="g"
            value={draft.fat}
            onChangeText={(t) => setField('fat', t)}
            error={validation?.fat}
          />
        </View>
      </View>

      {validation?.macroTotal ? <Text style={styles.error}>{validation.macroTotal}</Text> : null}
      {warning ? <Text style={styles.warning}>{warning}</Text> : null}
      {mode === 'portion' && <Text style={styles.hint}>Gespeichert wird automatisch umgerechnet auf 100 g.</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  modes: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginBottom: spacing.md },
  macroRow: { flexDirection: 'row', gap: spacing.sm },
  macro: { flex: 1 },
  error: { fontSize: 13, color: colors.danger, marginTop: -6, marginBottom: spacing.sm },
  warning: { fontSize: 13, color: colors.textMuted, marginTop: -4, marginBottom: spacing.sm, lineHeight: 18 },
  hint: { fontSize: 12, color: colors.textMuted, marginBottom: spacing.sm },
});
