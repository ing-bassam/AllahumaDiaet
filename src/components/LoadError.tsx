import { StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { CONTACT_EMAIL } from '../appInfo';
import { colors, spacing } from '../theme';
import { PrimaryButton } from './PrimaryButton';

type Props = {
  title?: string;
  onRetry: () => void;
  /** Zweiter Ausweg, z. B. „Schließen“ auf einem Detail-Screen. */
  onClose?: () => void;
};

/** Ersetzt einen Ladezustand, der sonst nach einem Datenbankfehler endlos stehen bliebe. */
export function LoadError({ title = 'Daten konnten nicht geladen werden', onRetry, onClose }: Props) {
  const insets = useSafeAreaInsets();
  return (
    <View style={[styles.container, { paddingTop: insets.top + spacing.lg, paddingBottom: insets.bottom + spacing.lg }]}>
      <Text style={styles.title} accessibilityRole="header">
        {title}
      </Text>
      <Text style={styles.body}>
        Bitte versuche es erneut. Hilft das nicht, starte die App neu. Tritt der Fehler weiter auf, schreib an {CONTACT_EMAIL}.
      </Text>
      <PrimaryButton label="Erneut versuchen" onPress={onRetry} style={styles.button} />
      {onClose ? <PrimaryButton label="Schließen" variant="secondary" onPress={onClose} style={styles.button} /> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: spacing.lg, gap: spacing.md, backgroundColor: colors.background },
  title: { fontSize: 20, fontWeight: '700', color: colors.text, textAlign: 'center' },
  body: { fontSize: 15, lineHeight: 21, color: colors.textMuted, textAlign: 'center' },
  button: { alignSelf: 'stretch' },
});
