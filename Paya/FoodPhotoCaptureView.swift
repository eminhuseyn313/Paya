import SwiftUI
import SwiftData
import UIKit

// MARK: - Food Photo Capture
// A single still photo is all this needs — no live preview/continuous
// scanning like the barcode/label scanners, so UIImagePickerController's
// camera mode is simpler and more reliable than hand-rolling an
// AVCaptureSession for this.

struct FoodPhotoPicker: UIViewControllerRepresentable {
    var onCaptured: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCaptured: onCaptured, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCaptured: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCaptured: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCaptured = onCaptured
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCaptured(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

// MARK: - Food Photo Estimate Sheet

struct FoodPhotoEstimateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    var vm: NutritionViewModel

    @State private var capturedImage: UIImage? = nil
    @State private var showCamera = true
    @State private var isLoading = false
    @State private var estimate: GeminiFoodService.Estimate? = nil
    @State private var errorText: String? = nil
    @State private var portionCount: Double = 1.0
    @State private var photoComment: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if appState.geminiAPIKey.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "key.slash")
                            .font(.system(size: 32))
                            .foregroundColor(Pulse.textTertiary)
                        Text("Add a free Gemini API key in Settings to use this.")
                            .font(.subheadline)
                            .foregroundColor(Pulse.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 24)
                } else if let capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if estimate == nil && !isLoading {
                        HStack(spacing: 8) {
                            Image(systemName: "text.bubble")
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                            TextField("Add context (e.g. 'large serving', 'just the chicken')", text: $photoComment)
                                .font(.subheadline)
                                .textFieldStyle(.roundedBorder)
                            if !photoComment.isEmpty {
                                Button {
                                    Task { await runEstimate(on: capturedImage) }
                                } label: {
                                    Text("Re-scan")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(Pulse.positive)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if isLoading {
                        SwiftUI.ProgressView("Estimating…")
                            .padding(.top, 12)
                    } else if let estimate {
                        portionSelector
                        estimateCard(estimate)
                    } else if let errorText {
                        Text(errorText)
                            .font(.caption)
                            .foregroundColor(Pulse.critical)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    Button {
                        self.capturedImage = nil
                        self.estimate = nil
                        self.errorText = nil
                        self.portionCount = 1.0
                        self.photoComment = ""
                        self.showCamera = true
                    } label: {
                        Text("Retake Photo")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 16)
                }

                Spacer()
            }
            .padding(.top, 8)
            .navigationTitle("Scan a Plate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                FoodPhotoPicker(
                    onCaptured: { image in
                        capturedImage = image
                        showCamera = false
                        Task { await runEstimate(on: image) }
                    },
                    onCancel: {
                        showCamera = false
                        if capturedImage == nil { dismiss() }
                    }
                )
                .ignoresSafeArea()
            }
        }
    }

    private var portionSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("My portion")
                .font(.caption.weight(.semibold))
                .foregroundColor(Pulse.textTertiary)
            HStack(spacing: 8) {
                ForEach([0.5, 1.0, 2.0, 3.0], id: \.self) { p in
                    Button {
                        portionCount = p
                    } label: {
                        Text(p == 0.5 ? "½" : p == 1.0 ? "All" : "1/\(Int(p))")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(portionCount == p ? Pulse.positive : Color(.tertiarySystemGroupedBackground))
                            .foregroundColor(portionCount == p ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            if portionCount != 1.0 {
                Text(portionCount < 1 ? "Logging half the plate" : "Plate shared \(Int(portionCount)) ways — logging your portion")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
            }
        }
        .padding(.horizontal, 16)
    }

    private var portionFraction: Double {
        portionCount <= 1.0 ? portionCount : 1.0 / portionCount
    }

    @ViewBuilder
    private func estimateCard(_ estimate: GeminiFoodService.Estimate) -> some View {
        let frac = portionFraction
        let adjProtein = estimate.proteinG * frac
        let adjCalories = estimate.calories * frac
        VStack(alignment: .leading, spacing: 10) {
            Text(estimate.foodName)
                .font(.headline)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(adjProtein))g")
                        .font(.title3.bold())
                        .foregroundColor(Pulse.hydration)
                    Text("protein")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(adjCalories))")
                        .font(.title3.bold())
                        .foregroundColor(Pulse.warning)
                    Text("kcal")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                }
            }
            MicronutrientChips(estimate: estimate, portionFraction: frac)
            if !estimate.confidence.isEmpty {
                Text(estimate.confidence)
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                let scaled = estimate.scaled(by: frac)
                vm.addMeal(
                    name: "Meal",
                    food: estimate.foodName,
                    protein: scaled.proteinG,
                    calories: scaled.calories,
                    context: modelContext,
                    estimate: scaled
                )
                dismiss()
            } label: {
                Text(portionCount == 1.0 ? "Log this" : "Log my portion")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Pulse.positive)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .payaCard(padding: 14)
        .padding(.horizontal, 16)
    }

    private func runEstimate(on image: UIImage) async {
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
            errorText = "Couldn't process that photo — try again."
            return
        }
        isLoading = true
        errorText = nil
        estimate = nil
        do {
            estimate = try await GeminiFoodService.estimateFromImage(
                jpegData,
                apiKey: appState.geminiAPIKey,
                userComment: photoComment.isEmpty ? nil : photoComment
            )
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}
