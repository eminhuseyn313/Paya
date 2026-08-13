import SwiftUI
import AVFoundation

// MARK: - Nutrition Label Scanner View
// Photographs a nutrition facts panel, runs on-device OCR, and hands back
// editable extracted macros for the caller to log.

struct NutritionLabelScannerView: View {

    @Environment(\.dismiss) private var dismiss

    var onExtracted: (ParsedNutritionLabel) -> Void

    @State private var flashOn = false
    @State private var cameraError: String? = nil
    @State private var isCapturing = false
    @State private var isAnalyzing = false
    @State private var captureRequested = false
    @State private var noResultFound = false

    var body: some View {
        ZStack {
            PhotoCapturePreview(
                flashOn: $flashOn,
                cameraError: $cameraError,
                captureRequested: $captureRequested,
                onPhotoCaptured: handleCapture
            )
            .ignoresSafeArea()

            ScannerOverlay()
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("Scan Nutrition Label")
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

                if cameraError != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill.badge.ellipsis")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                        Text(cameraError ?? "Camera unavailable")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Button("Close") { dismiss() }
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
                } else if isAnalyzing {
                    HStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("Reading label…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                } else if noResultFound {
                    VStack(spacing: 6) {
                        Text("Couldn't read the label")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                        Text("Fill the frame with just the Nutrition Facts panel and try again")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 30)
                } else {
                    Text("Fill the frame with the Nutrition Facts panel")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 30)
                }

                Button {
                    captureRequested = true
                    isCapturing = true
                    noResultFound = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 60, height: 60)
                    }
                }
                .disabled(isCapturing || isAnalyzing || cameraError != nil)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private func handleCapture(_ image: UIImage?) {
        isCapturing = false
        guard let image else {
            noResultFound = true
            return
        }
        isAnalyzing = true
        Task {
            let parsed = await NutritionLabelParser.parse(image: image)
            await MainActor.run {
                isAnalyzing = false
                if let parsed {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onExtracted(parsed)
                    dismiss()
                } else {
                    noResultFound = true
                }
            }
        }
    }
}

// MARK: - Photo Capture Preview (UIViewRepresentable)

struct PhotoCapturePreview: UIViewRepresentable {
    @Binding var flashOn: Bool
    @Binding var cameraError: String?
    @Binding var captureRequested: Bool
    var onPhotoCaptured: (UIImage?) -> Void

    func makeUIView(context: Context) -> PhotoCaptureUIView {
        let view = PhotoCaptureUIView()
        view.onCameraError = { error in
            DispatchQueue.main.async { cameraError = error }
        }
        view.onPhotoCaptured = { image in
            DispatchQueue.main.async { onPhotoCaptured(image) }
        }
        return view
    }

    func updateUIView(_ uiView: PhotoCaptureUIView, context: Context) {
        uiView.setFlash(flashOn)
        if captureRequested {
            uiView.capturePhoto()
            DispatchQueue.main.async { captureRequested = false }
        }
    }
}

class PhotoCaptureUIView: UIView {

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var device: AVCaptureDevice?
    private var photoDelegate: PhotoCaptureDelegate?

    var onCameraError: ((String) -> Void)?
    var onPhotoCaptured: ((UIImage?) -> Void)?

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
        session.sessionPreset = .photo
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

            let output = AVCapturePhotoOutput()
            guard session.canAddOutput(output) else {
                onCameraError?("Could not configure photo output")
                return
            }
            session.addOutput(output)
            self.photoOutput = output

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

    func capturePhoto() {
        guard let photoOutput else {
            onPhotoCaptured?(nil)
            return
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashActive() ? .on : .off
        let delegate = PhotoCaptureDelegate { [weak self] image in
            self?.onPhotoCaptured?(image)
        }
        self.photoDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func flashActive() -> Bool {
        device?.torchMode == .on
    }

    deinit {
        captureSession?.stopRunning()
    }
}

// MARK: - Confirm Sheet

struct LabelScanConfirmSheet: View {

    @Environment(\.dismiss) private var dismiss

    let label: ParsedNutritionLabel
    var onConfirm: (String, Double, Double) -> Void   // name, protein, calories

    @State private var name: String = "Scanned food"
    @State private var caloriesText: String
    @State private var proteinText: String

    init(label: ParsedNutritionLabel, onConfirm: @escaping (String, Double, Double) -> Void) {
        self.label = label
        self.onConfirm = onConfirm
        _caloriesText = State(initialValue: label.calories.map { String(Int($0)) } ?? "")
        _proteinText = State(initialValue: label.proteinG.map { String(format: "%.0f", $0) } ?? "")
    }

    private var canSave: Bool {
        Double(proteinText) != nil && Double(caloriesText) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Food name", text: $name)
                } header: {
                    Text("Name")
                }

                Section {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("kcal", text: $caloriesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("g", text: $proteinText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    if let carbs = label.carbsG {
                        HStack {
                            Text("Carbs (detected)")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(carbs))g").foregroundColor(.secondary)
                        }
                    }
                    if let fat = label.fatG {
                        HStack {
                            Text("Fat (detected)")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(fat))g").foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("From the label")
                } footer: {
                    Text("Double-check these — label OCR isn't perfect. Edit anything that looks off.")
                }
            }
            .navigationTitle("Confirm & Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log") {
                        guard let protein = Double(proteinText), let calories = Double(caloriesText) else { return }
                        onConfirm(name, protein, calories)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        completion(image)
    }
}
