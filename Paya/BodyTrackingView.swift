import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Body Tracking
// Measurements + progress photos — weight alone hides recomposition
// (losing fat while gaining muscle can show flat weight but real waist/arm
// change), and this entire category was missing from the app despite it
// being standard across every physique-tracking app in this space.

struct BodyTrackingView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var showMeasurementEntry = false
    @State private var measurements: [BodyMeasurementLog] = []
    @State private var photos: [ProgressPhoto] = []
    @State private var compareSelection: [ProgressPhoto] = []
    @State private var showCompare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: Measurements
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Measurements")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button {
                                showMeasurementEntry = true
                            } label: {
                                Label("Log", systemImage: "plus.circle.fill")
                                    .font(.caption.weight(.semibold))
                            }
                        }

                        if let latest = measurements.first {
                            MeasurementSummaryGrid(latest: latest, previous: measurements.dropFirst().first)
                        } else {
                            Text("No measurements logged yet — track neck, chest, waist, hips, arms, thighs, and calves to see recomposition weight alone can't show.")
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                                .padding(.vertical, 8)
                        }
                    }
                    .payaCard(padding: 14)
                    .padding(.horizontal, 16)

                    // MARK: Progress photos
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Progress Photos")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if compareSelection.count == 2 {
                                Button("Compare") { showCompare = true }
                                    .font(.caption.weight(.semibold))
                            }
                        }

                        ProgressPhotoCapture(onSaved: reload)

                        if photos.isEmpty {
                            Text("Photos tell you what the scale can't. Take one from the same angle every few weeks.")
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                                .padding(.vertical, 8)
                        } else {
                            Text("Tap two photos to compare side by side.")
                                .font(.caption2)
                                .foregroundColor(Pulse.textTertiary)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(photos) { photo in
                                    ProgressPhotoThumb(
                                        photo: photo,
                                        isSelected: compareSelection.contains(where: { $0.id == photo.id }),
                                        onTap: { toggleCompareSelection(photo) },
                                        onDelete: { delete(photo) }
                                    )
                                }
                            }
                        }
                    }
                    .payaCard(padding: 14)
                    .padding(.horizontal, 16)
                    .requiresPro()

                    Spacer().frame(height: 20)
                }
                .padding(.top, 12)
            }
            .navigationTitle("Body Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showMeasurementEntry) {
                MeasurementEntrySheet(onSaved: reload)
            }
            .sheet(isPresented: $showCompare) {
                if compareSelection.count == 2 {
                    PhotoCompareView(before: compareSelection[0], after: compareSelection[1])
                }
            }
            .onAppear { reload() }
        }
    }

    private func toggleCompareSelection(_ photo: ProgressPhoto) {
        if let idx = compareSelection.firstIndex(where: { $0.id == photo.id }) {
            compareSelection.remove(at: idx)
        } else {
            if compareSelection.count >= 2 { compareSelection.removeFirst() }
            compareSelection.append(photo)
        }
    }

    private func delete(_ photo: ProgressPhoto) {
        modelContext.delete(photo)
        try? modelContext.save()
        compareSelection.removeAll { $0.id == photo.id }
        reload()
    }

    private func reload() {
        let pid = ActiveProfile.id
        let mDescriptor = FetchDescriptor<BodyMeasurementLog>(
            predicate: #Predicate<BodyMeasurementLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        measurements = (try? modelContext.fetch(mDescriptor)) ?? []

        let pDescriptor = FetchDescriptor<ProgressPhoto>(
            predicate: #Predicate<ProgressPhoto> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        photos = (try? modelContext.fetch(pDescriptor)) ?? []
    }
}

// MARK: - Measurement Summary Grid

struct MeasurementSummaryGrid: View {
    let latest: BodyMeasurementLog
    let previous: BodyMeasurementLog?

    private var rows: [(label: String, current: Double?, prior: Double?)] {
        [
            ("Neck", latest.neckCm, previous?.neckCm),
            ("Chest", latest.chestCm, previous?.chestCm),
            ("Waist", latest.waistCm, previous?.waistCm),
            ("Hips", latest.hipsCm, previous?.hipsCm),
            ("Bicep", latest.bicepCm, previous?.bicepCm),
            ("Thigh", latest.thighCm, previous?.thighCm),
            ("Calf", latest.calfCm, previous?.calfCm)
        ]
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows.filter { $0.current != nil }, id: \.label) { row in
                HStack {
                    Text(row.label)
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                    Spacer()
                    Text(String(format: "%.1f cm", row.current ?? 0))
                        .font(.caption.weight(.semibold))
                    if let prior = row.prior, let current = row.current {
                        let delta = current - prior
                        if abs(delta) >= 0.1 {
                            Text(delta > 0 ? "+\(String(format: "%.1f", delta))" : String(format: "%.1f", delta))
                                .font(.caption2.weight(.bold))
                                .foregroundColor(delta > 0 ? Pulse.positive : Pulse.critical)
                        }
                    }
                }
            }
            Text("Last logged \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2)
                .foregroundColor(Pulse.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
    }
}

// MARK: - Measurement Entry Sheet

struct MeasurementEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onSaved: () -> Void

    @State private var neck: String = ""
    @State private var chest: String = ""
    @State private var waist: String = ""
    @State private var hips: String = ""
    @State private var bicep: String = ""
    @State private var thigh: String = ""
    @State private var calf: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("All in cm — leave blank to skip") {
                    measurementField("Neck", $neck)
                    measurementField("Chest", $chest)
                    measurementField("Waist", $waist)
                    measurementField("Hips", $hips)
                    measurementField("Bicep", $bicep)
                    measurementField("Thigh", $thigh)
                    measurementField("Calf", $calf)
                }
            }
            .navigationTitle("Log Measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func measurementField(_ label: String, _ binding: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("cm", text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func save() {
        let log = BodyMeasurementLog()
        log.profileId = ActiveProfile.id
        log.neckCm = Double(neck)
        log.chestCm = Double(chest)
        log.waistCm = Double(waist)
        log.hipsCm = Double(hips)
        log.bicepCm = Double(bicep)
        log.thighCm = Double(thigh)
        log.calfCm = Double(calf)
        guard log.hasAnyValue else { dismiss(); return }
        modelContext.insert(log)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSaved()
        dismiss()
    }
}

// MARK: - Progress Photo Capture

struct ProgressPhotoCapture: View {
    @Environment(\.modelContext) private var modelContext
    var onSaved: () -> Void

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var pendingAngle: ProgressPhoto.Angle = .front

    var body: some View {
        VStack(spacing: 8) {
            Picker("Angle", selection: $pendingAngle) {
                ForEach(ProgressPhoto.Angle.allCases) { angle in
                    Text(angle.displayName).tag(angle)
                }
            }
            .pickerStyle(.segmented)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Add \(pendingAngle.displayName.lowercased()) photo", systemImage: "camera.fill")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Pulse.hydration.opacity(0.1))
                    .foregroundColor(Pulse.hydration)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                guard let newItem, let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                let photo = ProgressPhoto(angleRaw: pendingAngle.rawValue, imageData: data)
                photo.profileId = ActiveProfile.id
                modelContext.insert(photo)
                try? modelContext.save()
                selectedItem = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSaved()
            }
        }
    }
}

// MARK: - Progress Photo Thumb

struct ProgressPhotoThumb: View {
    let photo: ProgressPhoto
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Text(photo.angle.displayName)
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.6))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .padding(4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Pulse.ai : .clear, lineWidth: 3)
            )
        }
        .buttonStyle(PulsePress())
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Photo Compare View

struct PhotoCompareView: View {
    @Environment(\.dismiss) private var dismiss
    let before: ProgressPhoto
    let after: ProgressPhoto

    @State private var mode: CompareMode = .sideBySide
    @State private var sliderPosition: CGFloat = 0.5

    enum CompareMode: String, CaseIterable {
        case sideBySide = "Side by Side"
        case slider = "Slider"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(CompareMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                switch mode {
                case .sideBySide:
                    sideBySideView
                case .slider:
                    sliderOverlayView
                }

                HStack(spacing: 24) {
                    dateLabel(before.date, label: "Before")
                    Spacer()
                    if let daysBetween = Calendar.current.dateComponents([.day], from: before.date, to: after.date).day {
                        Text("\(daysBetween) days")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(Pulse.hydration)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Pulse.hydration.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    dateLabel(after.date, label: "After")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .navigationTitle("Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var sideBySideView: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                photoFill(before, width: (geo.size.width - 2) / 2, height: geo.size.height)
                photoFill(after, width: (geo.size.width - 2) / 2, height: geo.size.height)
            }
        }
    }

    private var sliderOverlayView: some View {
        GeometryReader { geo in
            ZStack {
                photoFill(after, width: geo.size.width, height: geo.size.height)

                photoFill(before, width: geo.size.width, height: geo.size.height)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: sliderPosition * geo.size.width)
                            Spacer(minLength: 0)
                        }
                    )

                // Slider handle
                Rectangle()
                    .fill(.white)
                    .frame(width: 3, height: geo.size.height)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .position(x: sliderPosition * geo.size.width, y: geo.size.height / 2)

                Circle()
                    .fill(.white)
                    .frame(width: 32, height: 32)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Pulse.textPrimary)
                    )
                    .position(x: sliderPosition * geo.size.width, y: geo.size.height / 2)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        sliderPosition = max(0.05, min(0.95, value.location.x / geo.size.width))
                    }
            )
        }
    }

    private func photoFill(_ photo: ProgressPhoto, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            }
        }
    }

    private func dateLabel(_ date: Date, label: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundColor(Pulse.textTertiary)
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption.weight(.semibold))
        }
    }
}
