import { Platform } from 'react-native';

const NUMERIC_KEYBOARDS = ['numeric', 'number-pad', 'decimal-pad', 'phone-pad'];

export function isNumericKeyboard(keyboardType: string | undefined): boolean {
  return keyboardType !== undefined && NUMERIC_KEYBOARDS.includes(keyboardType);
}

/**
 * Die Zahlentastatur von iOS hat keine Bestätigungstaste. Mit einer Beschriftung legt React Native
 * über jede Zahlentastatur eine eigene Leiste mit dieser Taste; sie schließt die Tastatur und löst
 * onSubmitEditing aus. Eine gemeinsame InputAccessoryView für alle Felder funktioniert unter der
 * neuen Architektur nicht: Sie bindet sich einmalig an das erste passende Feld im Fenster
 * (RCTInputAccessoryComponentView, didMoveToWindow), später erscheinende Felder bekamen keine Taste.
 * Auf Android schließt die Zurück-Taste die Tastatur.
 */
export const numericAccessoryProps =
  Platform.OS === 'ios' ? ({ inputAccessoryViewButtonLabel: 'Fertig' } as const) : ({} as const);
