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
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "Nothing new yet",
                        systemImage: "bell.badge",
                        description: Text("Paya will keep your training, nutrition, recovery, and progress updates here.")
                    )
                } else {
                    List {
                        if !today.isEmpty { notificationSection("Today", records: today) }
                        if !earlier.isEmpty { notificationSection("Earlier", records: earlier) }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark all read") {
                        try? NotificationCenterStore.markAllRead(profileId: profileId, context: modelContext)
                    }
                    .disabled(records.allSatisfy { $0.readAt != nil })
                }
            }
        }
    }

    @ViewBuilder
    private func notificationSection(_ title: String, records: [NotificationRecord]) -> some View {
        Section(title) {
            ForEach(records, id: \.id) { record in
                Button {
                    try? NotificationCenterStore.markRead(record, context: modelContext)
                    dismiss()
                    onOpen(record)
                } label: {
                    NotificationCard(record: record)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        try? NotificationCenterStore.delete(record, context: modelContext)
                    } label: { Label("Delete", systemImage: "trash") }
                }
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
                    .foregroundColor(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Color(.secondarySystemBackground))
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
            Image(systemName: record.category.symbol)
                .font(.headline)
                .foregroundStyle(record.category.color)
                .frame(width: 36, height: 36)
                .background(record.category.color.opacity(0.13))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title).font(.subheadline.weight(record.readAt == nil ? .bold : .regular))
                Text(record.message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Text(record.createdAt, style: .relative).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if record.readAt == nil { Circle().fill(record.category.color).frame(width: 8, height: 8) }
        }
        .padding(.vertical, 3)
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
        case .training: return Color(hex: "2563EB")
        case .meal: return .orange
        case .supplement: return .purple
        case .hydration: return .cyan
        case .recovery: return .indigo
        case .weighIn: return .teal
        case .milestone: return Color(hex: "B45309")
        case .flareRisk: return .red
        case .restTimer: return .green
        case .medication: return Color(hex: "DC2626")
        case .eyeCare: return Color(hex: "0EA5E9")
        case .circadian: return Color(hex: "D97706")
        case .postWorkoutNutrition: return Color(hex: "059669")
        case .weeklyDigest: return Color(hex: "2563EB")
        }
    }
}
