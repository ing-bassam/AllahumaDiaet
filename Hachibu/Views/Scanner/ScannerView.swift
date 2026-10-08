import AVFoundation
import UIKit
import SwiftUI

struct ScannedKey: Identifiable, Equatable {
    var key: String
    var id: String { key }
}

/// Vollbild-Scanner. Ein erkannter Code öffnet den Produkt-Screen als Blatt darüber; nach dem Speichern
/// geht es wahlweise zurück zum Tagebuch oder direkt weiter mit dem nächsten Scan.
struct ScannerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var permission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var torchOn = false
    @State private var scanned: ScannedKey?
    @State private var notice: String?
    @State private var manualOpen = false
    @State private var manualCode = ""
    @State private var manualError: String?
    @State private var paused = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if permission == .authorized {
                BarcodeScannerView(isActive: scanned == nil && !manualOpen && !paused, torchOn: torchOn, onScan: handleScan)
                    .ignoresSafeArea()
                scanOverlay
            } else {
                permissionView
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .task {
            if permission == .notDetermined {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                permission = granted ? .authorized : .denied
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Die Berechtigung wird neu gelesen, wenn man aus den Einstellungen zurückkommt.
            if phase == .active { permission = AVCaptureDevice.authorizationStatus(for: .video) }
        }
        .sheet(item: $scanned) { item in
            NavigationStack {
                ProductView(key: item.key, fromScanner: true) { outcome in
                    switch outcome {
                    case .saved(let continueScanning):
                        scanned = nil
                        if !continueScanning { dismiss() }
                    case .cancelled:
                        scanned = nil
                    }
                }
            }
            .interactiveDismissDisabled(false)
        }
        .alert("Barcode-Nummer eingeben", isPresented: $manualOpen) {
            TextField("z. B. 4012345678901", text: $manualCode)
                .keyboardType(.numberPad)
            Button("Suchen") { submitManual() }
            Button("Abbrechen", role: .cancel) { manualCode = "" }
        } message: {
            Text(manualError ?? "Die 8 oder 13 Ziffern unter dem Barcode.")
        }
    }

    private var scanOverlay: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Scanner schließen")
                Spacer()
                Button {
                    torchOn.toggle()
                } label: {
                    Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.title3.weight(.semibold))
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel(torchOn ? "Taschenlampe aus" : "Taschenlampe an")
            }
            .padding()

            Spacer()

            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.9), lineWidth: 3)
                .frame(width: 280, height: 180)
                .overlay {
                    if let notice {
                        Text(notice)
                            .font(.subheadline.weight(.semibold))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }

            Text("Barcode in den Rahmen halten")
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.top, 16)

            Spacer()

            Button {
                manualError = nil
                manualOpen = true
            } label: {
                Label("Nummer eintippen", systemImage: "keyboard")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.bottom, 32)
        }
        .foregroundStyle(.white)
    }

    private var permissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera")
                .font(.system(size: 44))
            Text("Kamerazugriff benötigt")
                .font(.title2.weight(.bold))
            Text("Die Kamera wird nur zum Scannen von Barcodes verwendet. Es werden keine Fotos gespeichert.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if permission == .notDetermined {
                ProgressView()
            } else {
                Button("Einstellungen öffnen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Nummer eintippen") {
                manualError = nil
                manualOpen = true
            }
            .buttonStyle(.bordered)
            Button("Abbrechen") { dismiss() }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .foregroundStyle(Color.primary)
    }

    private func handleScan(_ payload: String, _ symbology: String) {
        guard scanned == nil, notice == nil else { return }
        if let key = Barcode.normalize(payload, symbology: symbology) {
            Haptics.success()
            scanned = ScannedKey(key: key)
        } else {
            // Z. B. QR-Code mit Werbelink statt Produktnummer.
            Haptics.warning()
            notice = "Kein Produktcode erkannt"
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                notice = nil
            }
        }
    }

    private func submitManual() {
        let digits = manualCode.filter { $0.isNumber }
        guard let key = Barcode.normalize(digits) else {
            manualError = "Ungültige Nummer. Bitte die 8 oder 13 Ziffern unter dem Barcode prüfen."
            manualCode = digits
            // Dialog erneut öffnen, damit die Meldung sichtbar wird.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                manualOpen = true
            }
            return
        }
        manualCode = ""
        manualError = nil
        Haptics.success()
        scanned = ScannedKey(key: key)
    }
}
