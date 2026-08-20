import SwiftUI
import SwiftData

// MARK: - Bathroom Log Model

@Model
final class BathroomLog {
    var id: UUID
    var profileId: UUID?
    var date: Date
    /// "poop" or "pee"
    var type: String
    /// Bristol stool scale 1–7 (only for poop)
    var bristolScale: Int?
    /// Optional color note
    var color: String?
    /// Optional note
    var note: String?

    init(type: String, bristolScale: Int? = nil, color: String? = nil, note: String? = nil) {
        self.id = UUID()
        self.profileId = ActiveProfile.id
        self.date = Date()
        self.type = type
        self.bristolScale = bristolScale
        self.color = color
        self.note = note
    }
}

// MARK: - Bathroom Tracking Card

struct BathroomTrackingCard: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BathroomLog.date, order: .reverse) private var allLogs: [BathroomLog]
    @State private var showLogSheet = false
    @State private var logType: String = "poop"

    private var todaysLogs: [BathroomLog] {
        let cal = Calendar.current
        let pid = ActiveProfile.id
        return allLogs.filter { $0.profileId == pid && cal.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    private var poopCount: Int { todaysLogs.filter { $0.type == "poop" }.count }
    private var peeCount: Int { todaysLogs.filter { $0.type == "pee" }.count }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "drop.halffull")
                    .font(.system(size: 13))
                    .foregroundColor(Pulse.hydration)
                Text("Bathroom")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Pulse.textPrimary)
                Spacer()
            }

            // Today's counts
            HStack(spacing: 16) {
                bathroomStat(icon: "💩", count: poopCount, label: "Poop") {
                    logType = "poop"
                    showLogSheet = true
                }
                bathroomStat(icon: "💧", count: peeCount, label: "Pee") {
                    logType = "pee"
                    showLogSheet = true
                }
            }

            // Recent timeline
            if !todaysLogs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TODAY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Pulse.textTertiary)
                        .tracking(1)

                    ForEach(todaysLogs.prefix(5)) { log in
                        HStack(spacing: 8) {
                            Text(log.type == "poop" ? "💩" : "💧")
                                .font(.system(size: 12))
                            Text(log.date, style: .time)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(Pulse.textSecondary)
                            if let bs = log.bristolScale {
                                Text("Bristol \(bs)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(bristolColor(bs))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(bristolColor(bs).opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            if let note = log.note, !note.isEmpty {
                                Text(note)
                                    .font(.system(size: 11))
                                    .foregroundColor(Pulse.textTertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .payaCard()
        .sheet(isPresented: $showLogSheet) {
            BathroomLogSheet(type: logType)
                .presentationDetents([.medium, .large])
        }
    }

    private func bathroomStat(icon: String, count: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(icon)
                        .font(.system(size: 20))
                    Text("\(count)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Pulse.surfaceFallback)
            .clipShape(RoundedRectangle(cornerRadius: Pulse.Radius.sm))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func bristolColor(_ scale: Int) -> Color {
        switch scale {
        case 1, 2: return Pulse.warning      // constipated
        case 3, 4: return Pulse.positive      // ideal
        case 5: return Pulse.recovery         // soft
        case 6, 7: return Pulse.critical      // loose/diarrhea
        default: return Pulse.textSecondary
        }
    }
}

// MARK: - Log Sheet

struct BathroomLogSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let type: String

    @State private var bristolScale: Int = 4
    @State private var note: String = ""
    @State private var showBristolInfo = false

    private var isPoop: Bool { type == "poop" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Type indicator
                    VStack(spacing: 8) {
                        Text(isPoop ? "💩" : "💧")
                            .font(.system(size: 48))
                        Text("Log \(isPoop ? "bowel movement" : "urination")")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Pulse.textPrimary)
                    }
                    .padding(.top, 12)

                    // Bristol Scale (poop only)
                    if isPoop {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Bristol Stool Scale")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Pulse.textPrimary)
                                Button {
                                    showBristolInfo.toggle()
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 13))
                                        .foregroundColor(Pulse.textTertiary)
                                }
                            }

                            if showBristolInfo {
                                VStack(alignment: .leading, spacing: 4) {
                                    bristolDesc(1, "Separate hard lumps", Pulse.warning)
                                    bristolDesc(2, "Lumpy sausage shape", Pulse.warning)
                                    bristolDesc(3, "Sausage with cracks", Pulse.positive)
                                    bristolDesc(4, "Smooth soft sausage ✓", Pulse.positive)
                                    bristolDesc(5, "Soft blobs with clear edges", Pulse.recovery)
                                    bristolDesc(6, "Mushy, fluffy pieces", Pulse.critical)
                                    bristolDesc(7, "Watery, no solid pieces", Pulse.critical)
                                }
                                .padding(12)
                                .background(Pulse.surfaceFallback)
                                .clipShape(RoundedRectangle(cornerRadius: Pulse.Radius.sm))
                            }

                            // Scale picker
                            HStack(spacing: 6) {
                                ForEach(1...7, id: \.self) { scale in
                                    Button {
                                        bristolScale = scale
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        Text("\(scale)")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .frame(width: 40, height: 40)
                                            .background(bristolScale == scale ? bristolColor(scale) : Pulse.surfaceFallback)
                                            .foregroundColor(bristolScale == scale ? .white : Pulse.textSecondary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                    }

                    // Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note (optional)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Pulse.textPrimary)
                        TextField("Any observations...", text: $note)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Pulse.surfaceFallback)
                            .clipShape(RoundedRectangle(cornerRadius: Pulse.Radius.sm))
                    }

                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    save()
                } label: {
                    Text("Log")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Pulse.hydration)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .background(Pulse.canvasFallback.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Log \(isPoop ? "Poop" : "Pee")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let log = BathroomLog(
            type: type,
            bristolScale: isPoop ? bristolScale : nil,
            note: note.isEmpty ? nil : note
        )
        modelContext.insert(log)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func bristolDesc(_ scale: Int, _ desc: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Text("\(scale)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .frame(width: 20, height: 20)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .clipShape(Circle())
            Text(desc)
                .font(.system(size: 12))
                .foregroundColor(Pulse.textSecondary)
        }
    }

    private func bristolColor(_ scale: Int) -> Color {
        switch scale {
        case 1, 2: return Pulse.warning
        case 3, 4: return Pulse.positive
        case 5: return Pulse.recovery
        case 6, 7: return Pulse.critical
        default: return Pulse.textSecondary
        }
    }
}
