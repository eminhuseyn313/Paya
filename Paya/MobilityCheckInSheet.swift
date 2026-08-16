import SwiftUI
import SwiftData

// MARK: - Mobility Store

enum MobilityStore {
    @MainActor
    static func todaysCheckIn(context: ModelContext) -> MobilityCheckIn? {
        let pid = ActiveProfile.id
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<MobilityCheckIn>(
            predicate: #Predicate { $0.date >= startOfDay && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    static func recent(daysBack: Int, context: ModelContext) -> [MobilityCheckIn] {
        let pid = ActiveProfile.id
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysBack, to: .now) ?? .now
        let descriptor = FetchDescriptor<MobilityCheckIn>(
            predicate: #Predicate { $0.date >= cutoff && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    static func save(shoulder: Int, hip: Int, ankle: Int, context: ModelContext) {
        let checkIn = MobilityCheckIn(shoulderScore: shoulder, hipScore: hip, ankleScore: ankle)
        checkIn.profileId = ActiveProfile.id
        context.insert(checkIn)
        try? context.save()
    }
}

// MARK: - Mobility Check-In Banner (offered once/day, before a session)

struct MobilityCheckInBanner: View {
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Pulse.recovery.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "figure.flexibility")
                        .font(.subheadline)
                        .foregroundColor(Pulse.recovery)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick mobility check")
                        .font(.caption.weight(.semibold))
                    Text("10 seconds — shoulders, hips, ankles, before you load them today")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
            }
            .padding(12)
            .background(Pulse.recovery.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Pulse.recovery.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(PulsePress())
    }
}

// MARK: - Mobility Check-In Sheet

struct MobilityCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var onSaved: () -> Void = {}

    @State private var shoulder: Int? = nil
    @State private var hip: Int? = nil
    @State private var ankle: Int? = nil

    private let labels = ["Tight", "OK", "Great"]

    private let tests: [(area: String, icon: String, test: String)] = [
        ("Shoulders", "figure.arms.open", "Raise both arms overhead — can you fully extend without arching your back?"),
        ("Hips", "figure.walk", "Stand on one leg for 5s, then squat halfway — any pinching or stiffness?"),
        ("Ankles", "figure.step.training", "Rock forward on your toes, then back on heels — smooth or restricted?"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Try each quick test, then rate how it felt.")
                    .font(.subheadline)
                    .foregroundColor(Pulse.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                ratingRow(title: tests[0].area, icon: tests[0].icon, test: tests[0].test, selection: $shoulder)
                ratingRow(title: tests[1].area, icon: tests[1].icon, test: tests[1].test, selection: $hip)
                ratingRow(title: tests[2].area, icon: tests[2].icon, test: tests[2].test, selection: $ankle)

                Spacer()

                Button {
                    MobilityStore.save(
                        shoulder: shoulder ?? 2,
                        hip: hip ?? 2,
                        ankle: ankle ?? 2,
                        context: modelContext
                    )
                    onSaved()
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Pulse.recovery)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(shoulder == nil || hip == nil || ankle == nil)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .navigationTitle("Mobility Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func ratingRow(title: String, icon: String, test: String, selection: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(Pulse.textTertiary)
                Text(title).font(.subheadline.weight(.semibold))
            }
            Text(test)
                .font(.caption)
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { score in
                    Button {
                        selection.wrappedValue = score
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(labels[score - 1])
                            .font(.caption.weight(.semibold))
                            .foregroundColor(selection.wrappedValue == score ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selection.wrappedValue == score ? Pulse.recovery : Pulse.surfaceElevatedFallback)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PulsePress())
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
