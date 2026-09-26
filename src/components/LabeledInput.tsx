import { StyleSheet, Text, TextInput, View, type TextInputProps } from 'react-native';

import { colors, radius } from '../theme';
import { isNumericKeyboard, numericAccessoryProps } from './numericKeyboard';

type Props = Omit<TextInputProps, 'style'> & { label: string; unit?: string; error?: string | null };

/** Beschriftetes Eingabefeld; standardmäßig mit Zahlen-Tastatur. */
export function LabeledInput({ label, unit, error, keyboardType = 'decimal-pad', ...inputProps }: Props) {
  return (
    <View style={styles.container}>
      <Text style={styles.label}>{label}</Text>
      <View style={[styles.inputRow, error ? { borderColor: colors.danger } : null]}>
        <TextInput
          {...(isNumericKeyboard(keyboardType) ? numericAccessoryProps : null)}
          {...inputProps}
          keyboardType={keyboardType}
          placeholderTextColor={colors.textMuted}
          style={styles.input}
        />
        {unit ? <Text style={styles.unit}>{unit}</Text> : null}
      </View>
      {error ? <Text style={styles.error}>{error}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { marginBottom: 14 },
  label: { fontSize: 14, fontWeight: '600', color: colors.text, marginBottom: 6 },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.sm,
    paddingHorizontal: 12,
  },
  input: { flex: 1, fontSize: 17, color: colors.text, paddingVertical: 12 },
  unit: { fontSize: 15, color: colors.textMuted, marginLeft: 8 },
  error: { fontSize: 13, color: colors.danger, marginTop: 4 },
});
