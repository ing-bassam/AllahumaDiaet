import { CameraView, useCameraPermissions, type BarcodeScanningResult } from 'expo-camera';
import * as Haptics from 'expo-haptics';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { AppState, KeyboardAvoidingView, Linking, Modal, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Icon } from '../components/Icon';
import { NumericDoneBar, numericAccessoryProps } from '../components/NumericDoneBar';
import { PrimaryButton } from '../components/PrimaryButton';
import { normalizeBarcode } from '../lib/barcode';
import { colors, radius, spacing } from '../theme';

const BOX_WIDTH = 280;
const BOX_HEIGHT = 180;

export default function Scanner() {
  const router = useRouter();
  // Tag, auf den der Eintrag gehört (aus der Startseite); fehlt er, gilt heute.
  const { date } = useLocalSearchParams<{ date?: string }>();
  const insets = useSafeAreaInsets();
  const [permission, requestPermission, getPermission] = useCameraPermissions();
  const [torch, setTorch] = useState(false);
  const [manualOpen, setManualOpen] = useState(false);
  const [manualCode, setManualCode] = useState('');
  const [manualError, setManualError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  // Die Kamera meldet denselben Code mehrmals pro Sekunde; nur den ersten verarbeiten.
  const handled = useRef(false);

  // Die Berechtigung wird nur beim Öffnen gelesen. Wer sie in den Systemeinstellungen erteilt und
  // zurückkommt, sähe sonst weiter den Hinweis – unter Android ohne erneute Abfrage eine Sackgasse.
  const granted = permission?.granted ?? false;
  useEffect(() => {
    if (granted) return;
    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') getPermission();
    });
    return () => subscription.remove();
  }, [granted, getPermission]);

  const openProduct = (barcode: string) => {
    handled.current = true;
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    router.replace({ pathname: '/product/[barcode]', params: { barcode, ...(date ? { date } : null) } });
  };

  const handleScan = ({ data, type }: BarcodeScanningResult) => {
    if (handled.current) return;
    const barcode = normalizeBarcode(data, type);
    if (barcode) {
      openProduct(barcode);
      return;
    }
    // Z. B. QR-Code mit Werbelink statt Produktnummer.
    handled.current = true;
    setNotice('Kein Produktcode erkannt');
    setTimeout(() => {
      setNotice(null);
      handled.current = false;
    }, 1500);
  };

  const submitManual = () => {
    const barcode = normalizeBarcode(manualCode);
    if (!barcode) {
      setManualError('Ungültige Nummer. Bitte die 8 oder 13 Ziffern unter dem Barcode prüfen.');
      return;
    }
    setManualOpen(false);
    openProduct(barcode);
  };

  if (!permission) return <View style={styles.black} />;

  if (!permission.granted) {
    return (
      <View style={[styles.permission, { paddingTop: insets.top + spacing.lg, paddingBottom: insets.bottom + spacing.lg }]}>
        <Text style={styles.permissionTitle}>Kamerazugriff benötigt</Text>
        <Text style={styles.permissionText}>
          Die Kamera wird nur zum Scannen von Barcodes verwendet. Es werden keine Fotos gespeichert.
        </Text>
        {permission.canAskAgain ? (
          <PrimaryButton label="Zugriff erlauben" onPress={requestPermission} />
        ) : (
          <PrimaryButton label="Einstellungen öffnen" onPress={() => Linking.openSettings()} />
        )}
        <PrimaryButton label="Nummer eintippen" variant="secondary" onPress={() => setManualOpen(true)} style={{ marginTop: spacing.sm }} />
        <PrimaryButton label="Stattdessen suchen" variant="secondary" onPress={() => router.replace({ pathname: '/search', params: date ? { date } : {} })} style={{ marginTop: spacing.sm }} />
        <PrimaryButton label="Abbrechen" variant="secondary" onPress={() => router.back()} style={{ marginTop: spacing.sm }} />
        {renderManualModal()}
      </View>
    );
  }

  function renderManualModal() {
    return (
      <Modal visible={manualOpen} transparent animationType="fade" onRequestClose={() => setManualOpen(false)}>
        <KeyboardAvoidingView style={styles.modalBackdrop} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <View style={styles.modalCard}>
            <Text style={styles.modalTitle}>Barcode-Nummer eingeben</Text>
            <TextInput
              {...numericAccessoryProps}
              value={manualCode}
              onChangeText={(t) => {
                setManualCode(t.replace(/\D/g, ''));
                setManualError(null);
              }}
              keyboardType="number-pad"
              autoFocus
              maxLength={14}
              placeholder="z. B. 4012345678901"
              placeholderTextColor={colors.textMuted}
              style={styles.modalInput}
              onSubmitEditing={submitManual}
            />
            {manualError && <Text style={styles.modalError}>{manualError}</Text>}
            <PrimaryButton label="Suchen" onPress={submitManual} disabled={manualCode.length < 8} />
            <PrimaryButton label="Abbrechen" variant="secondary" onPress={() => setManualOpen(false)} style={{ marginTop: spacing.sm }} />
          </View>
          <NumericDoneBar />
        </KeyboardAvoidingView>
      </Modal>
    );
  }

  return (
    <View style={styles.black}>
      <CameraView
        style={StyleSheet.absoluteFill}
        facing="back"
        enableTorch={torch}
        barcodeScannerSettings={{ barcodeTypes: ['ean13', 'ean8', 'upc_a', 'upc_e', 'qr'] }}
        onBarcodeScanned={manualOpen ? undefined : handleScan}
      />

      {/* Abgedunkelter Rahmen um die Fokus-Box */}
      <View style={StyleSheet.absoluteFill} pointerEvents="none">
        <View style={styles.dim} />
        <View style={{ flexDirection: 'row', height: BOX_HEIGHT }}>
          <View style={styles.dim} />
          <View style={styles.focusBox} />
          <View style={styles.dim} />
        </View>
        <View style={[styles.dim, styles.hintArea]}>
          <Text style={styles.hint}>{notice ?? 'Barcode in den Rahmen halten'}</Text>
        </View>
      </View>

      <View style={[styles.topBar, { top: insets.top + spacing.sm }]}>
        <Pressable onPress={() => router.back()} style={styles.roundButton} accessibilityLabel="Scanner schließen" hitSlop={8}>
          <Icon name="close" color="#fff" size={26} />
        </Pressable>
        <Pressable
          onPress={() => setTorch((t) => !t)}
          style={[styles.roundButton, torch && { backgroundColor: '#fff' }]}
          accessibilityLabel={torch ? 'Taschenlampe ausschalten' : 'Taschenlampe einschalten'}
          accessibilityState={{ selected: torch }}
          hitSlop={8}
        >
          <Icon name="flashlight" color={torch ? '#000' : '#fff'} size={24} />
        </Pressable>
      </View>

      <View style={[styles.bottomBar, { bottom: insets.bottom + spacing.lg }]}>
        <Pressable onPress={() => setManualOpen(true)} style={styles.manualButton} accessibilityRole="button">
          <Icon name="keyboard" color="#fff" size={22} />
          <Text style={styles.manualLabel}>Nummer eintippen</Text>
        </Pressable>
        <Pressable onPress={() => router.replace({ pathname: '/search', params: date ? { date } : {} })} hitSlop={8} style={styles.searchLink} accessibilityRole="link">
          <Text style={styles.searchLinkText}>Stattdessen suchen</Text>
        </Pressable>
      </View>

      {renderManualModal()}
    </View>
  );
}

const styles = StyleSheet.create({
  black: { flex: 1, backgroundColor: '#000' },
  dim: { flex: 1, backgroundColor: 'rgba(0,0,0,0.55)' },
  focusBox: {
    width: BOX_WIDTH,
    height: BOX_HEIGHT,
    borderWidth: 3,
    borderColor: '#fff',
    borderRadius: radius.md,
  },
  hintArea: { alignItems: 'center', paddingTop: spacing.lg },
  hint: { color: '#fff', fontSize: 16, fontWeight: '600' },
  topBar: { position: 'absolute', left: spacing.md, right: spacing.md, flexDirection: 'row', justifyContent: 'space-between' },
  roundButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(0,0,0,0.5)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  bottomBar: { position: 'absolute', left: 0, right: 0, alignItems: 'center' },
  manualButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 20,
    height: 50,
    borderRadius: radius.pill,
    backgroundColor: 'rgba(0,0,0,0.6)',
  },
  manualLabel: { color: '#fff', fontSize: 16, fontWeight: '600' },
  searchLink: { marginTop: spacing.md, paddingHorizontal: spacing.md, paddingVertical: spacing.xs, borderRadius: radius.pill, backgroundColor: 'rgba(0,0,0,0.45)' },
  searchLinkText: { color: '#fff', fontSize: 15, fontWeight: '600', textDecorationLine: 'underline' },
  permission: { flex: 1, backgroundColor: colors.background, paddingHorizontal: spacing.lg, justifyContent: 'center' },
  permissionTitle: { fontSize: 24, fontWeight: '800', color: colors.text, marginBottom: spacing.sm, textAlign: 'center' },
  permissionText: { fontSize: 16, color: colors.textMuted, textAlign: 'center', marginBottom: spacing.lg, lineHeight: 22 },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.6)', justifyContent: 'center', padding: spacing.lg },
  modalCard: { backgroundColor: colors.surface, borderRadius: radius.lg, padding: spacing.lg },
  modalTitle: { fontSize: 18, fontWeight: '700', color: colors.text, marginBottom: spacing.md },
  modalInput: {
    fontSize: 24,
    letterSpacing: 2,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.sm,
    paddingHorizontal: 12,
    paddingVertical: 12,
    marginBottom: spacing.sm,
    color: colors.text,
    fontVariant: ['tabular-nums'],
  },
  modalError: { color: colors.danger, fontSize: 13, marginBottom: spacing.sm },
});
