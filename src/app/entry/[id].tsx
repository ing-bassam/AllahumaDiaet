import { useLocalSearchParams, useRouter } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Chip } from '../../components/Chip';
import { Icon } from '../../components/Icon';
import { NumericDoneBar, numericAccessoryProps } from '../../components/NumericDoneBar';
import { NutritionFields, useNutritionEditor } from '../../components/NutritionFields';
import { PrimaryButton } from '../../components/PrimaryButton';
import { deleteLogEntry, getLogEntry, updateFoodNutrients, updateLogEntry, type LogEntryDetail } from '../../db/repository';
import { formatDecimal, formatInt, MEAL_TYPES, parseDecimal, toInputText, type MealType } from '../../lib/format';
import { nutrientsForPortion } from '../../lib/nutrition';
import { portionPresets, validPortionGrams } from '../../lib/portions';
import { colors, radius, spacing } from '../../theme';

export default function EntryScreen() {
  const db = useSQLiteContext();
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const [entry, setEntry] = useState<LogEntryDetail | null | undefined>(undefined);

  useEffect(() => {
    getLogEntry(db, String(id)).then(setEntry);
  }, [db, id]);

  if (entry === undefined) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  if (entry === null) {
    return (
      <View style={styles.centered}>
        <Text style={styles.muted}>Dieser Eintrag existiert nicht mehr.</Text>
        <PrimaryButton label="Schließen" variant="secondary" onPress={() => router.back()} style={styles.fullWidth} />
      </View>
    );
  }

  // Erst mit geladenem Eintrag rendern, damit die Formular-Hooks mit den echten Werten starten.
  return <EntryEditor entry={entry} />;
}

function EntryEditor({ entry }: { entry: LogEntryDetail }) {
  const db = useSQLiteContext();
  const router = useRouter();
  const insets = useSafeAreaInsets();

  const [amount, setAmount] = useState(toInputText(entry.grams));
  const [mealType, setMealType] = useState<MealType>(entry.mealType);
  const [editingNutrients, setEditingNutrients] = useState(false);
  const [applyToFood, setApplyToFood] = useState(false);
  const [saving, setSaving] = useState(false);

  const grams = parseDecimal(amount);
  const validGrams = validPortionGrams(grams);
  // Standardmäßig „pro Portion“: So steht es meist auf dem Teller bzw. der Verpackung.
  const editor = useNutritionEditor({ initialPer100g: entry.per100g, portionGrams: validGrams, initialMode: 'portion' });

  const nutrientsChanged = editingNutrients && editor.touched;
  const per100g = nutrientsChanged ? editor.per100g : entry.per100g;
  const portion = per100g ? nutrientsForPortion(per100g, validGrams ?? 0) : null;
  const canSave = validGrams !== null && (!nutrientsChanged || editor.isValid) && !saving;

  const save = async () => {
    if (!canSave || validGrams === null || !per100g) return;
    setSaving(true);
    try {
      await updateLogEntry(db, entry.id, {
        grams: validGrams,
        mealType,
        per100g: nutrientsChanged ? per100g : undefined,
      });
      // Auch ohne Änderung übernehmbar: z. B. wenn dieser Eintrag schon früher abweichende Werte bekommen hat.
      if (editingNutrients && applyToFood) {
        await updateFoodNutrients(db, entry.barcode, { per100g });
      }
      router.back();
    } catch {
      setSaving(false);
      Alert.alert('Speichern fehlgeschlagen', 'Bitte versuche es erneut.');
    }
  };

  const confirmDelete = () => {
    Alert.alert('Eintrag löschen?', `${entry.name} (${formatDecimal(entry.grams)} g)`, [
      { text: 'Abbrechen', style: 'cancel' },
      {
        text: 'Löschen',
        style: 'destructive',
        onPress: async () => {
          try {
            await deleteLogEntry(db, entry.id);
            router.back();
          } catch {
            Alert.alert('Löschen fehlgeschlagen', 'Bitte versuche es erneut.');
          }
        },
      },
    ]);
  };

  return (
    // Wie im Produkt-Screen: Die Tastatur verkleinert den Bereich, die Buttons bleiben erreichbar.
    <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <View style={[styles.header, { paddingTop: insets.top + spacing.sm }]}>
        <View style={styles.headerText}>
          <Text style={styles.name} numberOfLines={2}>
            {entry.name}
          </Text>
          {entry.brand ? (
            <Text style={styles.muted} numberOfLines={2}>
              {entry.brand}
            </Text>
          ) : null}
        </View>
        <Pressable onPress={() => router.back()} hitSlop={12} accessibilityLabel="Schließen" style={styles.closeButton}>
          <Icon name="close" color={colors.textMuted} />
        </Pressable>
      </View>

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
        // Auf iOS folgt die Tastatur dem Finger; zusaetzlicher Weg, sie ohne „Fertig“ zu schliessen.
        keyboardDismissMode={Platform.OS === 'ios' ? 'interactive' : 'on-drag'}
      >
        <View style={styles.amountRow}>
          <TextInput
            {...numericAccessoryProps}
            value={amount}
            onChangeText={setAmount}
            keyboardType="decimal-pad"
            selectTextOnFocus
            placeholder="0"
            placeholderTextColor={colors.border}
            style={styles.amountInput}
            maxLength={6}
            accessibilityLabel="Menge in Gramm"
          />
          <Text style={styles.amountUnit}>g</Text>
        </View>

        <View style={styles.totals}>
          <Text style={styles.totalKcal}>{portion ? `${formatInt(portion.calories)} kcal` : '– kcal'}</Text>
          {portion && (
            <Text style={styles.muted}>
              Protein {formatDecimal(portion.protein)} g · Kohlenhydrate {formatDecimal(portion.carbs)} g · Fett {formatDecimal(portion.fat)} g
            </Text>
          )}
        </View>

        <View style={styles.chips}>
          {portionPresets(entry.servingSizeG).map((preset) => (
            <Chip key={preset.label} label={preset.label} selected={grams === preset.grams} onPress={() => setAmount(toInputText(preset.grams))} />
          ))}
        </View>

        <View style={styles.chips}>
          {MEAL_TYPES.map((meal) => (
            <Chip key={meal.value} label={meal.label} selected={mealType === meal.value} onPress={() => setMealType(meal.value)} />
          ))}
        </View>

        <PrimaryButton
          label={editingNutrients ? 'Nährwerte ausblenden' : 'Nährwerte ändern'}
          variant="secondary"
          icon="pencil"
          trailingIcon={editingNutrients ? 'chevronUp' : 'chevronDown'}
          expanded={editingNutrients}
          onPress={() => setEditingNutrients((open) => !open)}
        />

        {editingNutrients && (
          <View style={[styles.panel, styles.panelSpacing]}>
            <Text style={styles.sectionLabel}>Nährwerte dieses Eintrags</Text>
            <NutritionFields editor={editor} />
            <View style={styles.switchRow}>
              <Text style={styles.switchLabel}>Auch für künftige Einträge dieses Lebensmittels übernehmen</Text>
              <Switch
                value={applyToFood}
                onValueChange={setApplyToFood}
                trackColor={{ true: colors.primary, false: colors.track }}
                accessibilityLabel="Auch für künftige Einträge dieses Lebensmittels übernehmen"
              />
            </View>
            {applyToFood && (
              <Text style={styles.hint}>
                Das Lebensmittel wird dauerhaft korrigiert. Andere, bereits eingetragene Tage bleiben unverändert.
              </Text>
            )}
          </View>
        )}
      </ScrollView>

      <View style={[styles.footer, { paddingBottom: insets.bottom + spacing.sm }]}>
        <PrimaryButton label="Speichern" onPress={save} disabled={!canSave} loading={saving} />
        <PrimaryButton label="Eintrag löschen" variant="danger" onPress={confirmDelete} style={{ marginTop: spacing.sm }} />
      </View>

      <NumericDoneBar />
    </KeyboardAvoidingView>
  );
}

// Schriftgröße der Grammzahl und die dazu passende Zeilenhöhe.
const AMOUNT_FONT_SIZE = 48;
// Feste Hoehe der Zeile; auf dem TextInput selbst darf kein lineHeight stehen,
// sonst schiebt iOS die Ziffern aus dem Feld heraus und sie ueberlagern die Kopfzeile.
const AMOUNT_ROW_HEIGHT = 72;

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  scroll: { flex: 1 },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.lg, gap: spacing.md, backgroundColor: colors.background },
  fullWidth: { alignSelf: 'stretch' },
  header: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.sm,
    gap: spacing.sm,
    backgroundColor: colors.background,
    zIndex: 1,
  },
  // flexShrink sorgt dafür, dass langer Text umbricht statt unter das X zu laufen.
  headerText: { flex: 1, flexShrink: 1, paddingRight: spacing.xs },
  name: { fontSize: 20, fontWeight: '700', color: colors.text, lineHeight: 26 },
  muted: { fontSize: 14, color: colors.textMuted },
  closeButton: { width: 36, height: 36, alignItems: 'center', justifyContent: 'center' },
  content: { padding: spacing.md, paddingBottom: spacing.xl },
  // Feste Zeilenhöhe und Höhe: Ohne sie ragen die großen Ziffern auf iOS aus dem Feld heraus
  // und überlagern die Kopfzeile darüber.
  amountRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    height: AMOUNT_ROW_HEIGHT,
    overflow: 'hidden',
  },
  amountInput: {
    fontSize: AMOUNT_FONT_SIZE,
    height: AMOUNT_ROW_HEIGHT,
    fontWeight: '800',
    color: colors.text,
    minWidth: 110,
    maxWidth: 220,
    textAlign: 'right',
    fontVariant: ['tabular-nums'],
    paddingVertical: 0,
    includeFontPadding: false,
  },
  amountUnit: { fontSize: 28, fontWeight: '700', color: colors.textMuted, marginLeft: 8 },
  totals: { alignItems: 'center', marginTop: spacing.sm, marginBottom: spacing.lg },
  totalKcal: { fontSize: 24, fontWeight: '800', color: colors.primary, fontVariant: ['tabular-nums'] },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginBottom: spacing.md },
  link: { fontSize: 14, fontWeight: '600', color: colors.primary, alignSelf: 'flex-start', paddingVertical: spacing.xs },
  panel: { backgroundColor: colors.surface, borderRadius: radius.lg, padding: spacing.md },
  panelSpacing: { marginTop: spacing.sm },
  sectionLabel: { fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: spacing.sm },
  switchRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, marginTop: spacing.sm },
  switchLabel: { flex: 1, fontSize: 14, color: colors.text, lineHeight: 20 },
  hint: { fontSize: 13, color: colors.textMuted, marginTop: spacing.xs, lineHeight: 18 },
  footer: {
    paddingHorizontal: spacing.md,
    paddingTop: spacing.sm,
    backgroundColor: colors.background,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: colors.border,
  },
});
