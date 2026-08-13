import SwiftUI
import SwiftData

struct TrainingHeatmapCard: View {

    @Environment(\.modelContext) private var modelContext
    @State private var dayData: [Date: Int] = [:]

    private let columns = 13
    private let rows = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundColor(Color(hex: "059669"))
                Text("Training Activity")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Last 13 weeks")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    weekdayLabels
                    ForEach(0..<columns, id: \.self) { col in
                        VStack(spacing: 2) {
                            ForEach(0..<rows, id: \.self) { row in
                                let date = dateFor(column: col, row: row)
                                let count = date.flatMap { dayData[$0] } ?? 0
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(cellColor(count: count, date: date))
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }

                HStack(spacing: 4) {
                    Spacer()
                    Text("Less")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    ForEach([0, 1, 2, 3], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(levelColor(level))
                            .frame(width: 10, height: 10)
                    }
                    Text("More")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }

            let totalSessions = dayData.values.reduce(0, +)
            let activeDays = dayData.values.filter { $0 > 0 }.count
            HStack(spacing: 16) {
                miniStat(label: "Sessions", value: "\(totalSessions)")
                miniStat(label: "Active days", value: "\(activeDays)")
                miniStat(label: "Avg/week", value: String(format: "%.1f", Double(totalSessions) / Double(columns)))
            }
            .font(.caption2)
        }
        .payaCard(padding: 14)
        .onAppear { loadData() }
    }

    /// Heatmap cell size based on container width (avoids deprecated UIScreen.main).
    /// The card sits inside 16pt horizontal padding + 14pt card padding on each side,
    /// plus weekday labels (~28pt) and inter-cell spacing.
    private func cellSize(in containerWidth: CGFloat) -> CGFloat {
        let available = containerWidth - 28 - (CGFloat(columns - 1) * 2)
        return max(8, available / CGFloat(columns))
    }

    // Fallback for computed uses outside GeometryReader
    private var cellSize: CGFloat {
        cellSize(in: 360) // conservative phone width
    }

    private var weekdayLabels: some View {
        VStack(spacing: 2) {
            ForEach(["M","T","W","T","F","S","S"], id: \.self) { label in
                Text(label)
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
                    .frame(width: 12, height: cellSize)
            }
        }
    }

    private func dateFor(column: Int, row: Int) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = (calendar.component(.weekday, from: today) + 5) % 7
        let endColumn = columns - 1
        let dayOffset = -((endColumn - column) * 7 + (todayWeekday - row))
        return calendar.date(byAdding: .day, value: dayOffset, to: today)
    }

    private func cellColor(count: Int, date: Date?) -> Color {
        guard let d = date, d <= Date() else {
            return Color(.systemBackground).opacity(0.3)
        }
        return levelColor(min(count, 3))
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 0: return Color(hex: "059669").opacity(0.08)
        case 1: return Color(hex: "059669").opacity(0.3)
        case 2: return Color(hex: "059669").opacity(0.6)
        default: return Color(hex: "059669")
        }
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption.weight(.bold))
            Text(label)
                .foregroundColor(.secondary)
        }
    }

    private func loadData() {
        let calendar = Calendar.current
        let pid = ActiveProfile.id
        let desc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.isCompleted == true }
        )
        let sessions = (try? modelContext.fetch(desc)) ?? []
        var data: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            data[day, default: 0] += 1
        }
        dayData = data
    }
}
