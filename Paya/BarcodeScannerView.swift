import SwiftUI
import AVFoundation

// MARK: - Barcode Scanner View

struct BarcodeScannerView: View {

    @Environment(\.dismiss) private var dismiss

    var onCodeScanned: (String) -> Void
    var onCancel: () -> Void

    @State private var scannedCode: String? = nil
    @State private var isProcessing = false
    @State private var flashOn = false
    @State private var cameraError: String? = nil

    var body: some View {
        ZStack {

            // Camera preview
            ScannerPreview(
                scannedCode: $scannedCode,
                flashOn: $flashOn,
                cameraError: $cameraError
            )
            .ignoresSafeArea()

            // Dim overlay with cutout
            ScannerOverlay()
                .ignoresSafeArea()

            VStack {

                // Top bar
                HStack {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("Scan Barcode")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                    Spacer()

                    Button {
                        flashOn.toggle()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: flashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(flashOn ? .yellow : .white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Flashlight")
                    .accessibilityAddTraits(flashOn ? .isSelected : [])
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                // Instructions
                if cameraError != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill.badge.ellipsis")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                        Text(cameraError ?? "Camera unavailable")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Button("Close") {
                            onCancel()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(.white)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 30)
                } else if isProcessing {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Looking up product...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                } else {
                    VStack(spacing: 8) {
                        Text("Point at a barcode")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Most food packages have a barcode on the back or side")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 40)
                }

                Spacer().frame(height: 60)
            }
        }
        .onChange(of: scannedCode) { _, code in
            guard let code = code, !isProcessing else { return }
            isProcessing = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCodeScanned(code)
        }
    }
}

// MARK: - Scanner Preview (UIViewRepresentable)

struct ScannerPreview: UIViewRepresentable {
    @Binding var scannedCode: String?
    @Binding var flashOn: Bool
    @Binding var cameraError: String?

    func makeUIView(context: Context) -> ScannerUIView {
        let view = ScannerUIView()
        view.onCodeScanned = { code in
            DispatchQueue.main.async {
                if scannedCode == nil {
                    scannedCode = code
                }
            }
        }
        view.onCameraError = { error in
            DispatchQueue.main.async {
                cameraError = error
            }
        }
        return view
    }

    func updateUIView(_ uiView: ScannerUIView, context: Context) {
        uiView.setFlash(flashOn)
    }
}

// MARK: - Scanner UIKit View

class ScannerUIView: UIView {

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var device: AVCaptureDevice?

    var onCodeScanned: ((String) -> Void)?
    var onCameraError: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCamera()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    private func setupCamera() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.configureSession()
                } else {
                    self?.onCameraError?("Camera permission denied. Enable in Settings.")
                }
            }
        }
    }

    private func configureSession() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video) else {
            onCameraError?("No camera available on this device")
            return
        }
        self.device = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                onCameraError?("Could not configure camera input")
                return
            }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                onCameraError?("Could not configure metadata output")
                return
            }
            session.addOutput(output)

            output.setMetadataObjectsDelegate(BarcodeDelegate.shared, queue: .main)
            output.metadataObjectTypes = [
                .ean8, .ean13, .upce, .code128, .code39, .code93, .qr
            ]

            BarcodeDelegate.shared.onCodeScanned = { [weak self] code in
                self?.onCodeScanned?(code)
            }

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = bounds
            layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer

            self.captureSession = session

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        } catch {
            onCameraError?("Camera setup failed: \(error.localizedDescription)")
        }
    }

    func setFlash(_ on: Bool) {
        guard let device = device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Flash error: \(error)")
        }
    }

    deinit {
        captureSession?.stopRunning()
    }
}

// MARK: - Metadata Delegate (singleton to avoid retain cycles)

class BarcodeDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {

    static let shared = BarcodeDelegate()
    var onCodeScanned: ((String) -> Void)?
    private var lastScanTime: Date = .distantPast

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Debounce: only fire once per second
        guard Date().timeIntervalSince(lastScanTime) > 1.0 else { return }

        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadata.stringValue else { return }

        lastScanTime = Date()
        onCodeScanned?(code)
    }
}

// MARK: - Scanner Overlay

struct ScannerOverlay: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.5)

                // Cutout rectangle
                RoundedRectangle(cornerRadius: 20)
                    .frame(width: geo.size.width * 0.8, height: 200)
                    .blendMode(.destinationOut)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 3)
                    )
            }
            .compositingGroup()
        }
    }
}
