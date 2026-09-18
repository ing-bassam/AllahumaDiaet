import { Redirect, useFocusEffect, useRouter } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Alert, AppState, Pressable, ScrollView, StyleSheet, Text, useWindowDimensions, View } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, { runOnJS, useAnimatedStyle, useSharedValue, withSpring, withTiming } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { CalendarSheet } from '../components/CalendarSheet';
import { CalorieRing } from '../components/CalorieRing';
import { Icon } from '../components/Icon';
import { MacroBar } from '../components/MacroBar';
import {
  deleteLogEntry,
  getDatesWithEntries,
  getEntriesForDate,
  getProfile,
  type LogEntryWithFood,
  type Profile,
} from '../db/repository';
import {
  addDays,
  dateKey,
  dayDateLine,
  dayTitle,
  endOfMonth,
  fullDateLabel,
  isSameDay,
  startOfDay,
  startOfMonth,
} from '../lib/date';
import { formatDecimal, formatInt, formatTime, MEAL_TYPES, type MealType } from '../lib/format';
import { macroGoalsInGrams, nutrientsForPortion, sumNutrients, type Nutrients } from '../lib/nutrition';
import { colors, radius, spacing } from '../theme';

type EntryWithTotals = LogEntryWithFood & { totals: Nutrients };

/** Nur Wischgesten, die am linken oder rechten Bildschirmrand beginnen, wechseln den Tag. */
const EDGE_WIDTH = 30;
/** Ab diesem Anteil der Bildschirmbreite bzw. dieser Geschwindigkeit wechselt der Tag. */
const SWIPE_DISTANCE_RATIO = 0.3;
const SWIPE_VELOCITY = 600;
const SLIDE_OUT_MS = 160;
const SLIDE_IN_MS = 200;

export default function Dashboard() {
  const db = useSQLiteContext();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { width } = useWindowDimensions();

  const [profile, setProfile] = useState<Profile | null | undefined>(undefined);
  const [entries, setEntries] = useState<EntryWithTotals[] | null>(null);
  const [today, setToday] = useState(() => startOfDay(new Date()));
  const [selectedDate, setSelectedDate] = useState(() => startOfDay(new Date()));
  const [collapsed, setCollapsed] = useState<Partial<Record<MealType, boolean>>>({});
  const [calendarOpen, setCalendarOpen] = useState(false);
  const [markedDates, setMarkedDates] = useState<string[]>([]);

  const todayRef = useRef(today);
  const selectedRef = useRef(selectedDate);
  todayRef.current = today;
  selectedRef.current = selectedDate;

  const translateX = useSharedValue(0);
  const fromEdge = useSharedValue(false);

  const isToday = isSameDay(selectedDate, today);
  const selectedKey = dateKey(selectedDate);

  const loadEntries = useCallback(
    async (key: string) => {
      const rows = await getEntriesForDate(db, key);
      // Nur übernehmen, wenn der Tag inzwischen nicht weitergewandert ist.
      if (dateKey(selectedRef.current) !== key) return;
      setEntries(rows.map((row) => ({ ...row, totals: nutrientsForPortion(row.per100g, row.grams) })));
    },
    [db],
  );

  /** War der ausgewählte Tag „heute“, wandert er nach Mitternacht auf den neuen heutigen Tag. */
  const refreshToday = useCallback(() => {
    const now = startOfDay(new Date());
    if (isSameDay(now, todayRef.current)) return;
    const selectedWasToday = isSameDay(selectedRef.current, todayRef.current);
    setToday(now);
    if (selectedWasToday) setSelectedDate(now);
  }, []);

  useFocusEffect(
    useCallback(() => {
      refreshToday();
      getProfile(db).then(setProfile);
      loadEntries(dateKey(selectedRef.current));
    }, [db, loadEntries, refreshToday]),
  );

  // Rückkehr aus dem Hintergrund: Datum prüfen, Daten neu laden.
  useEffect(() => {
    const subscription = AppState.addEventListener('change', (state) => {
      if (state !== 'active') return;
      refreshToday();
      loadEntries(dateKey(selectedRef.current));
    });
    return () => subscription.remove();
  }, [loadEntries, refreshToday]);

  useEffect(() => {
    // Alte Einträge sofort ausblenden, damit nie ein fremder Tag stehen bleibt.
    setEntries(null);
    loadEntries(selectedKey);
  }, [selectedKey, loadEntries]);

  const loadMonth = useCallback(
    async (month: Date) => {
      const dates = await getDatesWithEntries(db, dateKey(startOfMonth(month)), dateKey(endOfMonth(month)));
      setMarkedDates(dates);
    },
    [db],
  );

  /**
   * Zeigt den neuen Tag: Er startet am gegenueberliegenden Rand und gleitet herein.
   * Worklets koennen keine Date-Objekte kopieren, deshalb wandert nur der Zeitstempel ueber die Grenze.
   */
  const showDay = useCallback(
    (nextTime: number, direction: number) => {
      setSelectedDate(startOfDay(new Date(nextTime)));
      translateX.value = direction * width;
      translateX.value = withTiming(0, { duration: SLIDE_IN_MS });
    },
    [translateX, width],
  );

  /** Nach der Wischgeste: Der alte Inhalt ist schon draussen, jetzt nur noch den neuen Tag zeigen. */
  const commitStep = useCallback(
    (direction: number) => {
      showDay(addDays(selectedRef.current, direction).getTime(), direction);
    },
    [showDay],
  );

  /** Fuer Pfeile und Kalender: erst hinausgleiten, dann den neuen Tag zeigen. */
  const slideToDay = useCallback(
    (next: Date) => {
      setCalendarOpen(false);
      if (isSameDay(next, selectedRef.current)) return;

      const direction = next > selectedRef.current ? 1 : -1;
      const nextTime = startOfDay(next).getTime();
      translateX.value = withTiming(-direction * width, { duration: SLIDE_OUT_MS }, (finished) => {
        if (finished) runOnJS(showDay)(nextTime, direction);
      });
    },
    [showDay, translateX, width],
  );

  const stepDay = useCallback((direction: number) => slideToDay(addDays(selectedRef.current, direction)), [slideToDay]);

  const swipeDay = useMemo(
    () =>
      Gesture.Pan()
        // Erst bei klar waagerechter Bewegung aktivieren, sonst gehört die Geste der Liste.
        .activeOffsetX([-15, 15])
        .failOffsetY([-12, 12])
        .onBegin((event) => {
          fromEdge.value = event.x <= EDGE_WIDTH || event.x >= width - EDGE_WIDTH;
        })
        .onUpdate((event) => {
          if (fromEdge.value) translateX.value = event.translationX;
        })
        .onEnd((event) => {
          if (!fromEdge.value) return;
          const far = Math.abs(event.translationX) > width * SWIPE_DISTANCE_RATIO;
          const fast = Math.abs(event.velocityX) > SWIPE_VELOCITY;
          if (!far && !fast) {
            translateX.value = withSpring(0, { damping: 22, stiffness: 220 });
            return;
          }
          // Nach links wischen zeigt den nächsten Tag.
          const direction = event.translationX < 0 ? 1 : -1;
          translateX.value = withTiming(-direction * width, { duration: SLIDE_OUT_MS }, (finished) => {
            if (finished) runOnJS(commitStep)(direction);
          });
        })
        .onFinalize(() => {
          fromEdge.value = false;
        }),
    [commitStep, fromEdge, translateX, width],
  );

  const contentStyle = useAnimatedStyle(() => ({ transform: [{ translateX: translateX.value }] }));

  const shownEntries = entries ?? [];
  const totals = useMemo(() => sumNutrients(shownEntries.map((e) => e.totals)), [shownEntries]);

  if (profile === undefined) return <View style={styles.screen} />;
  if (profile === null) return <Redirect href="/onboarding" />;

  const macroGoals = macroGoalsInGrams(profile.dailyCalorieGoal, profile.macroSplit);

  const confirmDelete = (entry: EntryWithTotals) => {
    Alert.alert('Eintrag löschen?', `${entry.name} (${formatInt(entry.grams)} g)`, [
      { text: 'Abbrechen', style: 'cancel' },
      {
        text: 'Löschen',
        style: 'destructive',
        onPress: async () => {
          try {
            await deleteLogEntry(db, entry.id);
            loadEntries(selectedKey);
          } catch {
            Alert.alert('Löschen fehlgeschlagen', 'Bitte versuche es erneut.');
          }
        },
      },
    ]);
  };

  return (
    <View style={styles.screen}>
      <GestureDetector gesture={swipeDay}>
        <Animated.View style={[styles.flex, contentStyle]}>
          <ScrollView contentContainerStyle={{ paddingTop: insets.top + spacing.sm, paddingBottom: insets.bottom + 130 }}>
            <View style={styles.settingsRow}>
              <Pressable
                onPress={() => router.push('/onboarding')}
                hitSlop={12}
                accessibilityLabel="Profil und Ziele bearbeiten"
                style={styles.iconButton}
              >
                <Icon name="settings" color={colors.textMuted} />
              </Pressable>
            </View>

            <View style={styles.dayNav}>
              <Pressable onPress={() => stepDay(-1)} style={styles.dayArrow} accessibilityRole="button" accessibilityLabel="Vorheriger Tag">
                <Icon name="chevronLeft" color={colors.text} size={24} />
              </Pressable>

              <Pressable
                onPress={() => setCalendarOpen(true)}
                style={styles.dayLabels}
                accessibilityRole="button"
                accessibilityLabel={`Datum auswählen, aktuell ${fullDateLabel(selectedDate)}`}
              >
                <Text style={styles.title}>{dayTitle(selectedDate, today)}</Text>
                <Text style={styles.date}>{dayDateLine(selectedDate, today)}</Text>
              </Pressable>

              <Pressable onPress={() => stepDay(1)} style={styles.dayArrow} accessibilityRole="button" accessibilityLabel="Nächster Tag">
                <Icon name="chevronRight" color={colors.text} size={24} />
              </Pressable>
            </View>

            {!isToday && (
              <Pressable onPress={() => slideToDay(today)} style={styles.todayChip} accessibilityRole="button">
                <Text style={styles.todayChipText}>Zu heute</Text>
              </Pressable>
            )}

            <View style={styles.card}>
              <View style={styles.ringWrap}>
                <CalorieRing consumed={totals.calories} goal={profile.dailyCalorieGoal} />
              </View>
              <View style={styles.macros}>
                <MacroBar label="Protein" consumed={totals.protein} goal={macroGoals.protein} color={colors.protein} />
                <MacroBar label="Kohlenh." consumed={totals.carbs} goal={macroGoals.carbs} color={colors.carbs} />
                <MacroBar label="Fett" consumed={totals.fat} goal={macroGoals.fat} color={colors.fat} />
              </View>
            </View>

            {shownEntries.length === 0
              ? entries !== null && (
                  <Text style={styles.empty}>
                    {isToday ? 'Noch nichts eingetragen.\nTippe unten auf „Scannen“ oder die Lupe.' : 'An diesem Tag ist nichts eingetragen.'}
                  </Text>
                )
              : MEAL_TYPES.map(({ value, label }) => {
                  const mealEntries = shownEntries.filter((e) => e.mealType === value);
                  if (mealEntries.length === 0) return null;
                  const mealCalories = mealEntries.reduce((sum, e) => sum + e.totals.calories, 0);
                  const isCollapsed = collapsed[value] ?? false;

                  return (
                    <View key={value} style={styles.card}>
                      <Pressable
                        onPress={() => setCollapsed((c) => ({ ...c, [value]: !isCollapsed }))}
                        style={styles.mealHeader}
                        accessibilityRole="button"
                        accessibilityState={{ expanded: !isCollapsed }}
                      >
                        <Text style={styles.mealTitle}>{label}</Text>
                        <View style={styles.mealHeaderRight}>
                          <Text style={styles.mealCalories}>{formatInt(mealCalories)} kcal</Text>
                          <Icon name={isCollapsed ? 'chevronDown' : 'chevronUp'} size={20} color={colors.textMuted} />
                        </View>
                      </Pressable>

                      {!isCollapsed &&
                        mealEntries.map((entry) => (
                          <Pressable
                            key={entry.id}
                            onPress={() => router.push({ pathname: '/entry/[id]', params: { id: entry.id } })}
                            onLongPress={() => confirmDelete(entry)}
                            style={({ pressed }) => [styles.entry, pressed && { backgroundColor: colors.surfacePressed }]}
                            accessibilityRole="button"
                            accessibilityLabel={`${entry.name}, ${formatDecimal(entry.grams)} Gramm, ${formatInt(entry.totals.calories)} Kilokalorien`}
                            accessibilityHint="Tippen zum Bearbeiten, lange drücken zum Löschen"
                          >
                            <Text style={styles.entryTime}>{formatTime(entry.timestamp)}</Text>
                            <View style={styles.entryMain}>
                              <Text style={styles.entryName} numberOfLines={1}>
                                {entry.name}
                              </Text>
                              <Text style={styles.entryMeta} numberOfLines={1}>
                                {[entry.brand, `${formatDecimal(entry.grams)} g`].filter(Boolean).join(' · ')}
                              </Text>
                            </View>
                            <Text style={styles.entryCalories}>{formatInt(entry.totals.calories)}</Text>
                          </Pressable>
                        ))}
                    </View>
                  );
                })}

            {shownEntries.length > 0 && <Text style={styles.hint}>Tippen zum Bearbeiten</Text>}
            <Text style={styles.attribution}>Daten & Bilder: Open Food Facts (ODbL, CC BY-SA)</Text>
            <Pressable onPress={() => router.push('/about')} hitSlop={8} style={styles.aboutLink} accessibilityRole="link">
              <Text style={styles.aboutLinkText}>Info & Rechtliches</Text>
            </Pressable>
          </ScrollView>
        </Animated.View>
      </GestureDetector>

      <View style={[styles.fabWrap, { bottom: insets.bottom + spacing.md }]} pointerEvents="box-none">
        <Pressable
          onPress={() => router.push({ pathname: '/search', params: { date: selectedKey } })}
          accessibilityRole="button"
          accessibilityLabel="Lebensmittel suchen"
          style={({ pressed }) => [styles.searchButton, pressed && { backgroundColor: colors.surfacePressed }]}
        >
          <Icon name="search" color={colors.text} size={26} />
        </Pressable>
        <Pressable
          onPress={() => router.push({ pathname: '/scan', params: { date: selectedKey } })}
          accessibilityRole="button"
          accessibilityLabel="Barcode scannen"
          style={({ pressed }) => [styles.fab, pressed && { backgroundColor: colors.primaryPressed, transform: [{ scale: 0.97 }] }]}
        >
          <Icon name="scan" color={colors.onPrimary} size={28} />
          <Text style={styles.fabLabel}>Scannen</Text>
        </Pressable>
      </View>

      <CalendarSheet
        visible={calendarOpen}
        selectedDate={selectedDate}
        today={today}
        markedDates={markedDates}
        onMonthChange={loadMonth}
        onSelect={slideToDay}
        onClose={() => setCalendarOpen(false)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  flex: { flex: 1 },
  settingsRow: { flexDirection: 'row', justifyContent: 'flex-end', paddingHorizontal: spacing.sm },
  iconButton: { padding: spacing.sm },
  dayNav: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: spacing.sm },
  dayArrow: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center' },
  dayLabels: { flex: 1, alignItems: 'center', paddingVertical: spacing.xs },
  title: { fontSize: 28, fontWeight: '800', color: colors.text },
  date: { fontSize: 15, color: colors.textMuted },
  todayChip: {
    alignSelf: 'center',
    marginTop: spacing.xs,
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: radius.pill,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
  },
  todayChipText: { fontSize: 13, fontWeight: '600', color: colors.primary },
  card: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    marginHorizontal: spacing.md,
    marginTop: spacing.md,
    padding: spacing.md,
  },
  ringWrap: { alignItems: 'center', paddingVertical: spacing.sm },
  macros: { flexDirection: 'row', gap: spacing.md, marginTop: spacing.md },
  empty: { textAlign: 'center', color: colors.textMuted, fontSize: 16, lineHeight: 24, marginTop: spacing.lg },
  mealHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  mealHeaderRight: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  mealTitle: { fontSize: 17, fontWeight: '700', color: colors.text },
  mealCalories: { fontSize: 15, color: colors.textMuted, fontVariant: ['tabular-nums'] },
  entry: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: colors.border,
    marginTop: 10,
  },
  entryTime: { width: 48, fontSize: 13, color: colors.textMuted, fontVariant: ['tabular-nums'] },
  entryMain: { flex: 1, marginRight: spacing.sm },
  entryName: { fontSize: 15, fontWeight: '600', color: colors.text },
  entryMeta: { fontSize: 13, color: colors.textMuted },
  entryCalories: { fontSize: 15, fontWeight: '700', color: colors.text, fontVariant: ['tabular-nums'] },
  hint: { textAlign: 'center', color: colors.textMuted, fontSize: 12, marginTop: spacing.md },
  attribution: { textAlign: 'center', color: colors.textMuted, fontSize: 12, marginTop: spacing.sm },
  aboutLink: { alignSelf: 'center', paddingVertical: spacing.xs, marginTop: 2 },
  aboutLinkText: { color: colors.primary, fontSize: 13, fontWeight: '600' },
  // Such- und Scan-Button gemeinsam zentriert; Scannen bleibt primär und mindestens 64 pt hoch.
  fabWrap: { position: 'absolute', left: 0, right: 0, flexDirection: 'row', justifyContent: 'center', alignItems: 'center', gap: spacing.md },
  searchButton: {
    width: 60,
    height: 60,
    borderRadius: 30,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
    shadowColor: '#000',
    shadowOpacity: 0.12,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 4 },
    elevation: 4,
  },
  fab: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    height: 72,
    paddingHorizontal: 36,
    borderRadius: radius.pill,
    backgroundColor: colors.primary,
    shadowColor: '#000',
    shadowOpacity: 0.2,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 6 },
    elevation: 8,
  },
  fabLabel: { fontSize: 22, fontWeight: '800', color: colors.onPrimary },
});
