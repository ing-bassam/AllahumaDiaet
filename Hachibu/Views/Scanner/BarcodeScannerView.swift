import AVFoundation
import SwiftUI
import UIKit

/// Kamerabild mit Barcode-Erkennung über AVFoundation. Erkennt EAN-8, EAN-13, UPC-E und QR-Codes.
struct BarcodeScannerView: UIViewRepresentable {
    var isActive: Bool
    var torchOn: Bool
    var onScan: (String, String) -> Void

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.onScan = onScan
        view.configure()
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.onScan = onScan
        uiView.setRunning(isActive)
        uiView.setTorch(torchOn)
    }

    static func dismantleUIView(_ uiView: CameraPreviewView, coordinator: ()) {
        uiView.setTorch(false)
        uiView.setRunning(false)
    }
}

final class CameraPreviewView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "hachibu.camera")
    private var configured = false
    private var device: AVCaptureDevice?
    private var lastPayload: String?
    private var lastPayloadTime: Date = .distantPast

    var onScan: ((String, String) -> Void)?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    func configure() {
        guard !configured else { return }
        configured = true
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.session = session

        sessionQueue.async { [self] in
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera) else { return }
            device = camera
            session.beginConfiguration()
            if session.canAddInput(input) { session.addInput(input) }
            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                let wanted: [AVMetadataObject.ObjectType] = [.ean8, .ean13, .upce, .qr]
                output.metadataObjectTypes = wanted.filter { output.availableMetadataObjectTypes.contains($0) }
            }
            session.commitConfiguration()
        }
    }

    func setRunning(_ running: Bool) {
        sessionQueue.async { [self] in
            if running && !session.isRunning {
                session.startRunning()
            } else if !running && session.isRunning {
                session.stopRunning()
            }
        }
    }

    func setTorch(_ on: Bool) {
        sessionQueue.async { [self] in
            guard let device, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {
                // Ohne Taschenlampe weiter scannen.
            }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              let value = object.stringValue else { return }
        // Die Kamera meldet denselben Code mehrmals pro Sekunde; nur alle 1,5 s weitergeben.
        let now = Date()
        if value == lastPayload && now.timeIntervalSince(lastPayloadTime) < 1.5 { return }
        lastPayload = value
        lastPayloadTime = now
        onScan?(value, CameraPreviewView.symbologyName(object.type))
    }

    private static func symbologyName(_ type: AVMetadataObject.ObjectType) -> String {
        switch type {
        case .upce: return "upc_e"
        case .ean8: return "ean8"
        case .ean13: return "ean13"
        case .qr: return "qr"
        default: return type.rawValue
        }
    }
}
