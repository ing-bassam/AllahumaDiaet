import { InputAccessoryView, Keyboard, Platform, Pressable, StyleSheet, Text, View } from 'react-native';

import { colors, spacing } from '../theme';

/** Die Zahlentastatur von iOS hat keine Bestätigungstaste; diese Leiste liefert sie nach. */
export const NUMERIC_ACCESSORY_ID = 'numericKeyboardDone';

const NUMERIC_KEYBOARDS = ['numeric', 'number-pad', 'decimal-pad', 'phone-pad'];

export function isNumericKeyboard(keyboardType: string | undefined): boolean {
  return keyboardType !== undefined && NUMERIC_KEYBOARDS.includes(keyboardType);
}

/** Nur iOS kennt InputAccessoryView; auf Android schließt die Zurück-Taste die Tastatur. */
export const numericAccessoryProps =
  Platform.OS === 'ios' ? ({ inputAccessoryViewID: NUMERIC_ACCESSORY_ID } as const) : ({} as const);

export function NumericDoneBar() {
  if (Platform.OS !== 'ios') return null;

  return (
    <InputAccessoryView nativeID={NUMERIC_ACCESSORY_ID}>
      <View style={styles.bar}>
        <Pressable onPress={() => Keyboard.dismiss()} hitSlop={12} accessibilityRole="button" style={styles.button}>
          <Text style={styles.label}>Fertig</Text>
        </Pressable>
      </View>
    </InputAccessoryView>
  );
}

const styles = StyleSheet.create({
  bar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    // Feste Hoehe: ohne sie kann die Leiste in manchen Kontexten auf 0 zusammenfallen.
    minHeight: 44,
    backgroundColor: colors.surface,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: colors.border,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
  },
  button: { paddingHorizontal: spacing.sm, paddingVertical: spacing.sm },
  label: { fontSize: 17, fontWeight: '700', color: colors.primary },
});
