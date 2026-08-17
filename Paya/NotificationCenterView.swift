import SwiftUI
import SwiftData

struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NotificationRecord.createdAt, order: .reverse) private var allRecords: [NotificationRecord]

    let profileId: UUID
    let onOpen: (NotificationRecord) -> Void

    private var records: [NotificationRecord] {
        allRecords.filter { $0.profileId == profileId }
    }

    private var today: [NotificationRecord] {
        records.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    private var earlier: [NotificationRecord] {
        records.filter { !Calendar.current.isDateInToday($0.createdAt) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Pulse.canvasFallback.ignoresSafeArea()

                Group {
                    if records.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 48))
                                .foregroundColor(Pulse.textTertiary)
                                .shadow(color: Pulse.hydration.opacity(0.2), radius: 16)
                            Text("Nothing new yet")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Pulse.textPrimary)
                            Text("Paya will keep your training, nutrition, recovery, and progress updates here.")
                                .font(.system(size: 13))
                                .foregroundColor(Pulse.textTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 16) {
                                if !today.isEmpty { notificationSection("Today", records: today) }
                                if !earlier.isEmpty { notificationSection("Earlier", records: earlier) }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Notifications")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark all read") {
                        try? NotificationCenterStore.markAllRead(profileId: profileId, context: modelContext)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Pulse.hydration)
                    .disabled(records.allSatisfy { $0.readAt != nil })
                }
            }
        }
    }

    @ViewBuilder
    private func notificationSection(_ title: String, records: [NotificationRecord]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Pulse.textTertiary)
                .padding(.leading, 4)

            ForEach(records, id: \.id) { record in
                Button {
                    try? NotificationCenterStore.markRead(record, context: modelContext)
                    dismiss()
                    onOpen(record)
                } label: {
                    NotificationCard(record: record)
                }
                .buttonStyle(PulsePress())
            }
        }
    }
}

struct NotificationBellButton: View {
    let unreadCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell.fill")
                    .font(.title3)
                    .foregroundColor(Pulse.textTertiary)
                    .frame(width: 40, height: 40)
                    .background(Pulse.surfaceFallback)
                    .clipShape(Circle())
                if unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.red)
                        .clipShape(Capsule())
                        .offset(x: 6, y: -4)
                }
            }
        }
        .accessibilityLabel(unreadCount == 0 ? "Notifications" : "Notifications, \(unreadCount) unread")
    }
}

private struct NotificationCard: View {
    let record: NotificationRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(record.category.color.opacity(0.13))
                    .frame(width: 40, height: 40)
                Image(systemName: record.category.symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(record.category.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.system(size: 14, weight: record.readAt == nil ? .bold : .regular))
                    .foregroundColor(Pulse.textPrimary)
                Text(record.message)
                    .font(.system(size: 12))
                    .foregroundColor(Pulse.textTertiary)
                    .lineLimit(2)
                Text(record.createdAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(Pulse.textTertiary.opacity(0.6))
            }
            Spacer(minLength: 0)
            if record.readAt == nil {
                Circle()
                    .fill(record.category.color)
                    .frame(width: 8, height: 8)
                    .shadow(color: record.category.color.opacity(0.4), radius: 4)
            }
        }
        .payaCard(padding: 12)
    }
}

private extension NotificationCategory {
    var symbol: String {
        switch self {
        case .training: return "dumbbell.fill"
        case .meal: return "fork.knife"
        case .supplement: return "pills.fill"
        case .hydration: return "drop.fill"
        case .recovery: return "moon.stars.fill"
        case .weighIn: return "scalemass.fill"
        case .milestone: return "trophy.fill"
        case .flareRisk: return "flame.fill"
        case .restTimer: return "timer"
        case .medication: return "cross.vial.fill"
        case .eyeCare: return "eye.fill"
        case .circadian: return "sun.max.fill"
        case .postWorkoutNutrition: return "fork.knife.circle.fill"
        case .weeklyDigest: return "doc.text.magnifyingglass"
        }
    }
    var color: Color {
        switch self {
        case .training: return Pulse.hydration
        case .meal: return .orange
        case .supplement: return .purple
        case .hydration: return .cyan
        case .recovery: return .indigo
        case .weighIn: return .teal
        case .milestone: return Pulse.warning
        case .flareRisk: return .red
        case .restTimer: return .green
        case .medication: return Pulse.critical
        case .eyeCare: return Color(hex: "0EA5E9")
        case .circadian: return Color(hex: "D97706")
        case .postWorkoutNutrition: return Pulse.positive
        case .weeklyDigest: return Pulse.hydration
        }
    }
}
