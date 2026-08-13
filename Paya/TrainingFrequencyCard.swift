import SwiftUI
import SwiftData

struct TrainingFrequencyCard: View {

    @Environment(\.modelContext) private var modelContext
    @State private var dayOfWeekCounts: [Int] = Array(repeating: 0, count: 7)
    @State private var hourCounts: [Int] = Array(repeating: 0, count: 24)
    @State private var totalSessions: Int = 0
    @State private var favoriteDay: String = ""
    @State private var favoriteTime: String = ""

    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.badge.checkmark.fill")
                    .foregroundColor(Color(hex: "2563EB"))
                Text("When You Train")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            if totalSessions < 3 {
                Text("Complete a few more sessions to see your training patterns.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                // Day of week distribution
                VStack(alignment: .leading, spacing: 4) {
                    Text("BY DAY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { i in
                            let maxCount = dayOfWeekCounts.max() ?? 1
                            let intensity = maxCount > 0 ? Double(dayOfWeekCounts[i]) / Double(maxCount) : 0
                            VStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: "2563EB").opacity(max(0.08, intensity)))
                                    .frame(height: max(4, 30 * intensity))
                                Text(dayNames[i])
                                    .font(.system(size: 8, weight: dayOfWeekCounts[i] == dayOfWeekCounts.max() ? .bold : .regular))
                                    .foregroundColor(dayOfWeekCounts[i] == dayOfWeekCounts.max() ? .primary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 40)
                }

                // Time of day distribution
                VStack(alignment: .leading, spacing: 4) {
                    Text("BY TIME")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    let timeBlocks = groupedHours
                    HStack(spacing: 4) {
                        ForEach(timeBlocks, id: \.label) { block in
                            let maxBlock = timeBlocks.map(\.count).max() ?? 1
                            let intensity = maxBlock > 0 ? Double(block.count) / Double(maxBlock) : 0
                            VStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: "8B5CF6").opacity(max(0.08, intensity)))
                                    .frame(height: max(4, 24 * intensity))
                                Text(block.label)
                                    .font(.system(size: 7))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 34)
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "2563EB"))
                        Text("Favorite: \(favoriteDay)")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "8B5CF6"))
                        Text("Peak: \(favoriteTime)")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    Spacer()
                }
            }
        }
        .payaCard(padding: 14)
        .onAppear { loadData() }
    }

    private var groupedHours: [(label: String, count: Int)] {
        [
            (label: "5-8", count: hourCounts[5...7].reduce(0, +)),
            (label: "8-10", count: hourCounts[8...9].reduce(0, +)),
            (label: "10-12", count: hourCounts[10...11].reduce(0, +)),
            (label: "12-14", count: hourCounts[12...13].reduce(0, +)),
            (label: "14-16", count: hourCounts[14...15].reduce(0, +)),
            (label: "16-18", count: hourCounts[16...17].reduce(0, +)),
            (label: "18-20", count: hourCounts[18...19].reduce(0, +)),
            (label: "20-23", count: hourCounts[20...22].reduce(0, +)),
        ]
    }

    private func loadData() {
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.isCompleted && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let sessions = try? modelContext.fetch(descriptor) else { return }
        totalSessions = sessions.count

        let calendar = Calendar.current
        var dayCounts = Array(repeating: 0, count: 7)
        var hrCounts = Array(repeating: 0, count: 24)

        for session in sessions {
            var dow = calendar.component(.weekday, from: session.date) - 2
            if dow < 0 { dow = 6 }
            dayCounts[dow] += 1

            let hour = calendar.component(.hour, from: session.date)
            hrCounts[hour] += 1
        }

        dayOfWeekCounts = dayCounts
        hourCounts = hrCounts

        if let maxIdx = dayCounts.enumerated().max(by: { $0.element < $1.element })?.offset {
            favoriteDay = dayNames[maxIdx]
        }

        let blocks = groupedHours
        if let bestBlock = blocks.max(by: { $0.count < $1.count }) {
            favoriteTime = bestBlock.label
        }
    }
}
