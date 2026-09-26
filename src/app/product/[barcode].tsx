import * as Haptics from 'expo-haptics';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Image,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { USER_AGENT } from '../../appInfo';
import { Chip } from '../../components/Chip';
import { Icon } from '../../components/Icon';
import { LabeledInput } from '../../components/LabeledInput';
import { numericAccessoryProps } from '../../components/numericKeyboard';
import { NutritionFields, useNutritionEditor } from '../../components/NutritionFields';
import { PrimaryButton } from '../../components/PrimaryButton';
import {
  addLogEntry,
  foodPer100g,
  getFoodItem,
  restoreFoodFromOpenFoodFacts,
  saveFoodItem,
  updateFoodNutrients,
  type FoodItem,
  type NewFoodItem,
} from '../../db/repository';
import { combineDayWithTime, parseDateKey } from '../../lib/date';
import { isCustomFoodKey, parseFoodKey } from '../../lib/foodKey';
import { chooseFoodSource } from '../../lib/foodSource';
import { defaultMealType, formatDecimal, formatInt, MEAL_TYPES, parseDecimal, toInputText, type MealType } from '../../lib/format';
import { nutrientsForPortion } from '../../lib/nutrition';
import { fetchProduct, type PartialProduct } from '../../lib/openFoodFacts';
import { portionPresets, validPortionGrams } from '../../lib/portions';
import { getSearchHit } from '../../lib/searchHandoff';
import { colors, radius, spacing } from '../../theme';

type ScreenState =
  | { kind: 'loading' }
  | { kind: 'invalid' }
  /** `persisted: false` = Daten von Open Food Facts, noch nicht in food_item gespeichert. */
  | { kind: 'ready'; food: FoodItem; persisted: boolean }
  | { kind: 'manual'; reason: 'not_found' | 'incomplete' | 'error' | 'custom'; prefill: PartialProduct | null };

const asUnsaved = (item: NewFoodItem): FoodItem => ({ ...item, userEdited: false, updatedAt: null });

export default function ProductScreen() {
  const db = useSQLiteContext();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  // `barcode` ist eine GTIN oder ein `custom:`-Schlüssel; `name` füllt ein neues eigenes Lebensmittel vor.
  const params = useLocalSearchParams<{ barcode: string; name?: string; date?: string }>();
  const foodKey = parseFoodKey(String(params.barcode ?? ''));
  const initialName = typeof params.name === 'string' ? params.name : '';
  // Ohne Parameter bucht der Eintrag auf heute – wie vor der Tagesnavigation.
  const selectedDay = typeof params.date === 'string' ? parseDateKey(params.date) : null;

  const [state, setState] = useState<ScreenState>({ kind: 'loading' });

  const lookup = useCallback(async () => {
    if (!foodKey) {
      setState({ kind: 'invalid' });
      return;
    }
    setState({ kind: 'loading' });

    // Zuerst lokal: schnell, offline nutzbar und korrigierte Werte gewinnen (chooseFoodSource).
    const local = await getFoodItem(db, foodKey);
    if (chooseFoodSource({ local, remote: 'missing' }) === 'local' && local) {
      setState({ kind: 'ready', food: local, persisted: true });
      return;
    }

    if (isCustomFoodKey(foodKey)) {
      const prefill = { barcode: foodKey, name: initialName, brand: '', servingSizeG: null, imageUrl: null };
      setState({ kind: 'manual', reason: 'custom', prefill });
      return;
    }

    // Aus der Online-Suche übernommen: kein zweiter Abruf, noch nichts in der Datenbank.
    const result = getSearchHit(foodKey) ?? (await fetchProduct(foodKey, USER_AGENT));
    if (result.status === 'found') {
      // Erst beim Speichern des Eintrags (oder einer Korrektur) landet das Produkt in food_item.
      setState({ kind: 'ready', food: asUnsaved({ ...result.product, source: 'openfoodfacts' }), persisted: false });
    } else if (result.status === 'incomplete') {
      setState({ kind: 'manual', reason: 'incomplete', prefill: result.partial });
    } else {
      setState({ kind: 'manual', reason: result.status, prefill: null });
    }
  }, [db, foodKey, initialName]);

  useEffect(() => {
    lookup();
  }, [lookup]);

  const title = state.kind === 'manual' ? (state.reason === 'custom' ? 'Eigenes Lebensmittel' : 'Nährwerte eingeben') : 'Eintragen';

  return (
    <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <View style={[styles.header, { paddingTop: insets.top + spacing.sm }]}>
        <Pressable onPress={() => router.back()} hitSlop={12} accessibilityLabel="Zurück" style={styles.headerButton}>
          <Icon name="close" color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>{title}</Text>
        <View style={styles.headerButton} />
      </View>

      {state.kind === 'loading' && (
        <View style={styles.centered}>
          <ActivityIndicator size="large" color={colors.primary} />
          <Text style={styles.muted}>Produkt wird gesucht …</Text>
        </View>
      )}

      {state.kind === 'invalid' && (
        <View style={styles.centered}>
          <Text style={styles.muted}>Dieser Code ist kein gültiger Produkt-Barcode.</Text>
          <PrimaryButton label="Erneut scannen" onPress={() => router.replace('/scan')} style={{ marginTop: spacing.md, alignSelf: 'stretch' }} />
        </View>
      )}

      {state.kind === 'manual' && foodKey && (
        <ManualEntryForm
          barcode={foodKey}
          reason={state.reason}
          prefill={state.prefill}
          onRetry={lookup}
          onSaved={(food) => setState({ kind: 'ready', food, persisted: true })}
        />
      )}

      {state.kind === 'ready' && (
        <PortionForm
          food={state.food}
          persisted={state.persisted}
          day={selectedDay}
          onFoodChange={(food) => setState({ kind: 'ready', food, persisted: true })}
          onSaved={() => {
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
            router.dismissTo('/');
          }}
        />
      )}

    </KeyboardAvoidingView>
  );
}

type PortionFormProps = {
  food: FoodItem;
  persisted: boolean;
  /** Tag, auf den der Eintrag gebucht wird; `null` bedeutet heute. */
  day: Date | null;
  onFoodChange: (food: FoodItem) => void;
  onSaved: () => void;
};

function PortionForm({ food, persisted, day, onFoodChange, onSaved }: PortionFormProps) {
  const db = useSQLiteContext();
  const insets = useSafeAreaInsets();
  const [amount, setAmount] = useState('');
  const [mealType, setMealType] = useState<MealType>(() => defaultMealType(new Date()));
  const [saving, setSaving] = useState(false);
  const [correcting, setCorrecting] = useState(false);
  const [restoring, setRestoring] = useState(false);

  const grams = parseDecimal(amount);
  const validGrams = validPortionGrams(grams);
  const per100g = foodPer100g(food);
  const portion = nutrientsForPortion(per100g, validGrams ?? 0);
  const canRestore = food.userEdited && !isCustomFoodKey(food.barcode);
  const presets = portionPresets(food.servingSizeG);

  // Sperrt sofort und nicht erst mit dem nächsten Rendern: Die Fertig-Taste der Tastatur ruft save
  // direkt auf, und ein doppeltes Antippen schriebe denselben Eintrag sonst zweimal ins Tagebuch.
  const saveInFlight = useRef(false);
  const save = async () => {
    if (validGrams === null || saveInFlight.current) return;
    saveInFlight.current = true;
    setSaving(true);
    try {
      // Erst das Produkt, dann der Eintrag: log_entry verweist per Fremdschlüssel darauf.
      if (!persisted) await saveFoodItem(db, food);
      // Datum des gewählten Tages, Uhrzeit von jetzt.
      const at = day ? combineDayWithTime(day, new Date()) : undefined;
      await addLogEntry(db, { barcode: food.barcode, grams: validGrams, mealType, per100g, at });
      onSaved();
    } catch {
      Alert.alert('Speichern fehlgeschlagen', 'Der Eintrag konnte nicht gespeichert werden. Bitte versuche es erneut.');
    } finally {
      saveInFlight.current = false;
      setSaving(false);
    }
  };

  const restore = () => {
    Alert.alert('Eigene Werte verwerfen?', 'Die Nährwerte werden neu von Open Food Facts geladen.', [
      { text: 'Abbrechen', style: 'cancel' },
      {
        text: 'Wiederherstellen',
        onPress: async () => {
          setRestoring(true);
          try {
            const result = await fetchProduct(food.barcode, USER_AGENT);
            if (result.status !== 'found') {
              const message =
                result.status === 'error'
                  ? 'Keine Verbindung zu Open Food Facts. Bitte versuche es später erneut.'
                  : result.status === 'incomplete'
                    ? 'Bei Open Food Facts fehlen Nährwerte für dieses Produkt. Deine eigenen Werte bleiben erhalten.'
                    : 'Open Food Facts kennt dieses Produkt nicht. Deine eigenen Werte bleiben erhalten.';
              Alert.alert('Wiederherstellen nicht möglich', message);
              return;
            }
            await restoreFoodFromOpenFoodFacts(db, result.product);
            const updated = await getFoodItem(db, food.barcode);
            if (updated) onFoodChange(updated);
          } catch {
            Alert.alert('Wiederherstellen fehlgeschlagen', 'Bitte versuche es erneut.');
          } finally {
            setRestoring(false);
          }
        },
      },
    ]);
  };

  return (
    <>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled" keyboardDismissMode="on-drag">
        <View style={styles.productRow}>
          {food.imageUrl ? (
            <Image source={{ uri: food.imageUrl }} style={styles.productImage} resizeMode="contain" />
          ) : (
            <View style={[styles.productImage, styles.imagePlaceholder]}>
              <Icon name="scan" color={colors.textMuted} />
            </View>
          )}
          <View style={{ flex: 1 }}>
            <Text style={styles.productName} numberOfLines={2}>
              {food.name}
            </Text>
            {food.brand ? (
              <Text style={styles.muted} numberOfLines={2}>
                {food.brand}
              </Text>
            ) : null}
            <Text style={styles.per100}>
              pro 100 g: {formatInt(food.caloriesPer100g)} kcal · P {formatDecimal(food.proteinPer100g)} · K{' '}
              {formatDecimal(food.carbsPer100g)} · F {formatDecimal(food.fatPer100g)}
            </Text>
            {food.userEdited && (
              <View style={styles.nutrientActions}>
                <View style={styles.badge}>
                  <Text style={styles.badgeText}>Eigene Werte</Text>
                </View>
              </View>
            )}
          </View>
        </View>

        <PrimaryButton
          label={correcting ? 'Nährwerte ausblenden' : 'Nährwerte korrigieren'}
          variant="secondary"
          icon="pencil"
          trailingIcon={correcting ? 'chevronUp' : 'chevronDown'}
          expanded={correcting}
          onPress={() => setCorrecting((open) => !open)}
          style={styles.correctButton}
        />

        {canRestore && !correcting && (
          <Text style={[styles.link, styles.restoreLink]} suppressHighlighting onPress={restoring ? undefined : restore} accessibilityRole="button">
            {restoring ? 'Wird geladen …' : 'Werte von Open Food Facts wiederherstellen'}
          </Text>
        )}

        {correcting && (
          <CorrectionPanel
            food={food}
            persisted={persisted}
            portionGrams={validGrams}
            onCancel={() => setCorrecting(false)}
            onSaved={(updated) => {
              setCorrecting(false);
              onFoodChange(updated);
            }}
          />
        )}

        <View style={styles.amountRow}>
          <TextInput
            {...numericAccessoryProps}
            value={amount}
            onChangeText={setAmount}
            keyboardType="decimal-pad"
            autoFocus
            placeholder="0"
            placeholderTextColor={colors.border}
            style={styles.amountInput}
            maxLength={6}
            accessibilityLabel="Menge in Gramm"
            returnKeyType="done"
            // Auf iOS schließt „Fertig“ nur die Tastatur, damit noch die Mahlzeit gewählt werden kann.
            onSubmitEditing={Platform.OS === 'android' ? save : undefined}
          />
          <Text style={styles.amountUnit}>g</Text>
        </View>

        <View style={styles.totals}>
          <Text style={styles.totalKcal}>{formatInt(portion.calories)} kcal</Text>
          <Text style={styles.muted}>
            Protein {formatDecimal(portion.protein)} g · Kohlenhydrate {formatDecimal(portion.carbs)} g · Fett {formatDecimal(portion.fat)} g
          </Text>
        </View>

        <View style={styles.chips}>
          {presets.map((preset) => (
            <Chip key={preset.label} label={preset.label} selected={grams === preset.grams} onPress={() => setAmount(toInputText(preset.grams))} />
          ))}
        </View>

        <View style={styles.chips}>
          {MEAL_TYPES.map((meal) => (
            <Chip key={meal.value} label={meal.label} selected={mealType === meal.value} onPress={() => setMealType(meal.value)} />
          ))}
        </View>
      </ScrollView>

      {!correcting && (
        <View style={[styles.footer, { paddingBottom: insets.bottom + spacing.sm }]}>
          <PrimaryButton label="Speichern" onPress={save} disabled={validGrams === null} loading={saving} />
        </View>
      )}
    </>
  );
}

type CorrectionPanelProps = {
  food: FoodItem;
  persisted: boolean;
  portionGrams: number | null;
  onCancel: () => void;
  onSaved: (food: FoodItem) => void;
};

function CorrectionPanel({ food, persisted, portionGrams, onCancel, onSaved }: CorrectionPanelProps) {
  const db = useSQLiteContext();
  const [name, setName] = useState(food.name);
  const [brand, setBrand] = useState(food.brand);
  const [saving, setSaving] = useState(false);
  const editor = useNutritionEditor({ initialPer100g: foodPer100g(food), portionGrams });

  const canSave = name.trim() !== '' && editor.isValid && !saving;

  const save = async () => {
    if (!canSave || !editor.per100g) return;
    setSaving(true);
    try {
      // Stammt das Produkt frisch von Open Food Facts, erst anlegen, dann als korrigiert markieren.
      if (!persisted) await saveFoodItem(db, food);
      await updateFoodNutrients(db, food.barcode, { per100g: editor.per100g, name: name.trim(), brand: brand.trim() });
      const updated = await getFoodItem(db, food.barcode);
      if (updated) onSaved(updated);
    } catch {
      Alert.alert('Speichern fehlgeschlagen', 'Die Korrektur konnte nicht gespeichert werden. Bitte versuche es erneut.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <View style={styles.panel}>
      <Text style={styles.sectionLabel}>Nährwerte korrigieren</Text>
      <LabeledInput label="Name" keyboardType="default" value={name} onChangeText={setName} />
      <LabeledInput label="Marke (optional)" keyboardType="default" value={brand} onChangeText={setBrand} />
      <NutritionFields editor={editor} />
      <Text style={styles.panelHint}>Gilt ab jetzt für dieses Produkt. Bereits eingetragene Tage bleiben unverändert.</Text>
      <PrimaryButton label="Korrektur speichern" onPress={save} disabled={!canSave} loading={saving} />
      <PrimaryButton label="Abbrechen" variant="secondary" onPress={onCancel} style={{ marginTop: spacing.sm }} />
    </View>
  );
}

const REASON_TEXT = {
  not_found: 'Dieses Produkt ist noch nicht in der Datenbank. Gib die Nährwerte einmalig ein – beim nächsten Scan sind sie sofort da.',
  incomplete: 'Für dieses Produkt fehlen Nährwerte. Bitte ergänze sie einmalig von der Verpackung.',
  error: 'Keine Verbindung zur Produktdatenbank. Du kannst es erneut versuchen oder die Nährwerte von der Verpackung eintippen.',
  custom: 'Lege ein eigenes Lebensmittel ohne Barcode an. Es wird auf deinem Gerät gespeichert und ist über die Suche wieder auffindbar.',
} as const;

type ManualProps = {
  barcode: string;
  reason: keyof typeof REASON_TEXT;
  prefill: PartialProduct | null;
  onRetry: () => void;
  onSaved: (food: FoodItem) => void;
};

function ManualEntryForm({ barcode, reason, prefill, onRetry, onSaved }: ManualProps) {
  const db = useSQLiteContext();
  const insets = useSafeAreaInsets();
  const [name, setName] = useState(prefill?.name ?? '');
  const [brand, setBrand] = useState(prefill?.brand ?? '');
  const [packageSize, setPackageSize] = useState(prefill?.servingSizeG ? toInputText(prefill.servingSizeG) : '');
  const [saving, setSaving] = useState(false);

  const packageValue = parseDecimal(packageSize);
  const packageError = packageSize.trim() !== '' && (packageValue === null || packageValue <= 0) ? 'Ungültige Menge.' : null;
  // Viele Etiketten nennen Werte pro Packung oder Portion – die Packungsgröße dient dann als Umrechnungsbasis.
  const editor = useNutritionEditor({
    initialPer100g: null,
    portionGrams: packageValue !== null && packageValue > 0 ? packageValue : null,
    portionLabel: 'pro Packung',
    portionIsBasis: true,
  });

  const canSave = name.trim() !== '' && editor.isValid && !packageError && !saving;

  const save = async () => {
    if (!canSave || !editor.per100g) return;
    setSaving(true);
    try {
      const food: NewFoodItem = {
        barcode,
        name: name.trim(),
        brand: brand.trim(),
        caloriesPer100g: editor.per100g.calories,
        proteinPer100g: editor.per100g.protein,
        carbsPer100g: editor.per100g.carbs,
        fatPer100g: editor.per100g.fat,
        servingSizeG: packageValue && packageValue > 0 ? packageValue : null,
        imageUrl: prefill?.imageUrl ?? null,
        source: 'manual',
      };
      await saveFoodItem(db, food);
      onSaved(asUnsaved(food));
    } catch {
      Alert.alert('Speichern fehlgeschlagen', 'Das Lebensmittel konnte nicht gespeichert werden. Bitte versuche es erneut.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled" keyboardDismissMode="on-drag">
        <Text style={styles.reason}>{REASON_TEXT[reason]}</Text>
        {reason === 'error' && (
          <PrimaryButton label="Erneut versuchen" variant="secondary" onPress={onRetry} style={{ marginBottom: spacing.md }} />
        )}
        {!isCustomFoodKey(barcode) && <Text style={styles.barcode}>Barcode {barcode}</Text>}

        <LabeledInput
          label={reason === 'custom' ? 'Name' : 'Produktname'}
          keyboardType="default"
          value={name}
          onChangeText={setName}
          placeholder={reason === 'custom' ? 'z. B. Omas Linsensuppe' : 'z. B. Magerquark'}
          autoFocus={!prefill?.name}
        />
        <LabeledInput label="Marke (optional)" keyboardType="default" value={brand} onChangeText={setBrand} />
        <LabeledInput
          label={reason === 'custom' ? 'Übliche Portion (optional)' : 'Packungsgröße (optional)'}
          unit="g"
          value={packageSize}
          onChangeText={setPackageSize}
          error={packageError}
        />

        <Text style={styles.sectionLabel}>Nährwerte</Text>
        <NutritionFields editor={editor} autoFocus={Boolean(prefill?.name)} />
      </ScrollView>

      <View style={[styles.footer, { paddingBottom: insets.bottom + spacing.sm }]}>
        <PrimaryButton label={reason === 'custom' ? 'Lebensmittel speichern' : 'Produkt speichern'} onPress={save} disabled={!canSave} loading={saving} />
      </View>
    </>
  );
}

const AMOUNT_FONT_SIZE = 48;
// Kein lineHeight auf dem TextInput: iOS schiebt die Ziffern sonst aus dem Feld.
const AMOUNT_ROW_HEIGHT = 72;

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.sm,
    paddingBottom: spacing.sm,
  },
  headerButton: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center' },
  headerTitle: { fontSize: 17, fontWeight: '700', color: colors.text },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.lg, gap: spacing.sm },
  content: { padding: spacing.md, paddingBottom: spacing.lg },
  muted: { fontSize: 14, color: colors.textMuted },
  productRow: { flexDirection: 'row', gap: spacing.md, alignItems: 'flex-start', marginBottom: spacing.lg },
  productImage: { width: 72, height: 72, borderRadius: radius.md, backgroundColor: colors.surface },
  imagePlaceholder: { alignItems: 'center', justifyContent: 'center' },
  productName: { fontSize: 20, fontWeight: '700', color: colors.text },
  per100: { fontSize: 12, color: colors.textMuted, marginTop: 4 },
  nutrientActions: { flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', gap: spacing.sm, marginTop: 6 },
  badge: { backgroundColor: colors.background, borderRadius: radius.pill, paddingHorizontal: 8, paddingVertical: 2 },
  badgeText: { fontSize: 11, fontWeight: '600', color: colors.textMuted },
  link: { fontSize: 13, fontWeight: '600', color: colors.primary },
  restoreLink: { marginTop: spacing.sm, marginBottom: spacing.sm },
  correctButton: { marginBottom: spacing.md },
  panel: { backgroundColor: colors.surface, borderRadius: radius.lg, padding: spacing.md, marginBottom: spacing.lg },
  panelHint: { fontSize: 13, color: colors.textMuted, marginBottom: spacing.md, lineHeight: 18 },
  // Wie im Eintrag-Fenster: feste Zeilenhöhe, damit die Ziffern im Feld bleiben.
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
  footer: {
    paddingHorizontal: spacing.md,
    paddingTop: spacing.sm,
    backgroundColor: colors.background,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: colors.border,
  },
  reason: { fontSize: 15, color: colors.text, lineHeight: 21, marginBottom: spacing.md },
  barcode: { fontSize: 13, color: colors.textMuted, marginBottom: spacing.md, fontVariant: ['tabular-nums'] },
  sectionLabel: { fontSize: 16, fontWeight: '700', color: colors.text, marginTop: spacing.sm, marginBottom: spacing.sm },
});
