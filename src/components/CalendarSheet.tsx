import { useEffect, useState } from 'react';
import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { Gesture, GestureDetector, GestureHandlerRootView } from 'react-native-gesture-handler';
import { runOnJS } from 'react-native-reanimated';

import { monthMatrix, WEEKDAY_LABELS } from '../lib/calendar';
import { addMonths, dateKey, fullDateLabel, isSameDay, monthLabel, startOfMonth } from '../lib/date';
import { colors, radius, spacing } from '../theme';
import { Icon } from './Icon';
import { PrimaryButton } from './PrimaryButton';

const CELL_SIZE = 40;
const MONTH_SWIPE_DISTANCE = 50;

type Props = {
  visible: boolean;
  selectedDate: Date;
  today: Date;
  /** Datumsschlüssel mit Einträgen im gerade angezeigten Monat. */
  markedDates: string[];
  /** Meldet den angezeigten Monat, damit die Punkte dafür geladen werden. */
  onMonthChange: (month: Date) => void;
  onSelect: (date: Date) => void;
  onClose: () => void;
};

export function CalendarSheet({ visible, selectedDate, today, markedDates, onMonthChange, onSelect, onClose }: Props) {
  const [month, setMonth] = useState(() => startOfMonth(selectedDate));

  // Beim Öffnen immer den Monat des ausgewählten Tages zeigen.
  useEffect(() => {
    if (!visible) return;
    // Dasselbe Objekt behalten, wenn der Monat schon stimmt: Ein neues Date-Objekt gälte als Änderung
    // und löste die Monatsabfrage unten bei jedem Öffnen ein zweites Mal aus.
    setMonth((current) => {
      const next = startOfMonth(selectedDate);
      return current.getTime() === next.getTime() ? current : next;
    });
  }, [visible, selectedDate]);

  useEffect(() => {
    if (visible) onMonthChange(month);
  }, [visible, month, onMonthChange]);

  const changeMonth = (delta: number) => setMonth((current) => addMonths(current, delta));

  // Wischen wechselt den Monat; nur klar waagerechte Bewegungen.
  const swipeMonth = Gesture.Pan()
    .activeOffsetX([-20, 20])
    .failOffsetY([-20, 20])
    .onEnd((event) => {
      if (event.translationX <= -MONTH_SWIPE_DISTANCE) runOnJS(changeMonth)(1);
      else if (event.translationX >= MONTH_SWIPE_DISTANCE) runOnJS(changeMonth)(-1);
    });

  const marked = new Set(markedDates);
  const weeks = monthMatrix(month);

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <GestureHandlerRootView style={styles.root}>
        <Pressable style={styles.backdrop} onPress={onClose} accessibilityLabel="Kalender schließen" />
        <View style={styles.centered} pointerEvents="box-none">
          <GestureDetector gesture={swipeMonth}>
            <View style={styles.card}>
              <View style={styles.header}>
                <Pressable onPress={() => changeMonth(-1)} style={styles.arrow} accessibilityRole="button" accessibilityLabel="Vorheriger Monat">
                  <Icon name="chevronLeft" color={colors.text} size={22} />
                </Pressable>
                <Text style={styles.monthLabel}>{monthLabel(month)}</Text>
                <Pressable onPress={() => changeMonth(1)} style={styles.arrow} accessibilityRole="button" accessibilityLabel="Nächster Monat">
                  <Icon name="chevronRight" color={colors.text} size={22} />
                </Pressable>
                <Pressable onPress={onClose} style={styles.close} accessibilityRole="button" accessibilityLabel="Kalender schließen">
                  <Icon name="close" color={colors.textMuted} size={20} />
                </Pressable>
              </View>

              <View style={styles.weekdays}>
                {WEEKDAY_LABELS.map((label) => (
                  <Text key={label} style={styles.weekday}>
                    {label}
                  </Text>
                ))}
              </View>

              {weeks.map((week, weekIndex) => (
                <View key={weekIndex} style={styles.week}>
                  {week.map((day, dayIndex) => {
                    if (!day) return <View key={dayIndex} style={styles.cell} />;

                    const selected = isSameDay(day, selectedDate);
                    const isToday = isSameDay(day, today);
                    const hasEntries = marked.has(dateKey(day));

                    return (
                      <Pressable
                        key={dayIndex}
                        onPress={() => onSelect(day)}
                        style={styles.cell}
                        accessibilityRole="button"
                        accessibilityState={{ selected }}
                        accessibilityLabel={`${fullDateLabel(day)}${hasEntries ? ', Einträge vorhanden' : ''}`}
                      >
                        <View style={[styles.dayCircle, isToday && styles.todayCircle, selected && styles.selectedCircle]}>
                          <Text style={[styles.dayText, selected && styles.selectedText]}>{day.getDate()}</Text>
                        </View>
                        <View style={[styles.dot, hasEntries && styles.dotVisible, selected && styles.dotOnSelected]} />
                      </Pressable>
                    );
                  })}
                </View>
              ))}

              <PrimaryButton label="Heute" variant="secondary" onPress={() => onSelect(today)} style={styles.todayButton} />
            </View>
          </GestureDetector>
        </View>
      </GestureHandlerRootView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  backdrop: { ...StyleSheet.absoluteFill, backgroundColor: 'rgba(0,0,0,0.45)' },
  centered: { flex: 1, justifyContent: 'center', padding: spacing.md },
  card: { backgroundColor: colors.surface, borderRadius: radius.lg, padding: spacing.md },
  header: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.sm },
  arrow: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center' },
  monthLabel: { flex: 1, textAlign: 'center', fontSize: 17, fontWeight: '700', color: colors.text },
  close: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center' },
  weekdays: { flexDirection: 'row', marginBottom: spacing.xs },
  weekday: { flex: 1, textAlign: 'center', fontSize: 12, color: colors.textMuted },
  week: { flexDirection: 'row' },
  cell: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: 2 },
  dayCircle: { width: CELL_SIZE, height: CELL_SIZE, borderRadius: CELL_SIZE / 2, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderColor: 'transparent' },
  todayCircle: { borderColor: colors.primary },
  selectedCircle: { backgroundColor: colors.primary, borderColor: colors.primary },
  dayText: { fontSize: 15, color: colors.text, fontVariant: ['tabular-nums'] },
  selectedText: { color: colors.onPrimary, fontWeight: '700' },
  dot: { width: 5, height: 5, borderRadius: 2.5, marginTop: 2, backgroundColor: 'transparent' },
  dotVisible: { backgroundColor: colors.primary },
  dotOnSelected: { backgroundColor: 'transparent' },
  todayButton: { marginTop: spacing.md },
});
