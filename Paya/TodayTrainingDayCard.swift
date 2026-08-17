import SwiftUI
import SwiftData

struct TodayTrainingDayCard: View {

    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: Int

    @State private var todayDay: DaySnapshot? = nil
    @State private var exercises: [String] = []

    var body: some View {
        Button {
            selectedTab = 1
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    if let day = todayDay {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(day.color.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Text(day.code)
                                .font(.title.bold())
                                .foregroundColor(day.color)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(day.name)
                                .font(.headline)
                                .foregroundColor(Pulse.textPrimary)
                            Text(day.focus)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(day.color)
                            Text("Today")
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundColor(day.color)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Pulse.positive.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Image(systemName: "moon.zzz.fill")
                                .font(.title2)
                                .foregroundColor(Pulse.positive)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Rest day")
                                .font(.headline)
                                .foregroundColor(Pulse.textPrimary)
                            Text("Recovery + nutrition focus")
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                        }
                        Spacer()
                    }
                }

                if let day = todayDay, !exercises.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                    HStack(spacing: 6) {
                        ForEach(exercises.prefix(4), id: \.self) { name in
                            Text(shortName(name))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(day.color)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(day.color.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        if exercises.count > 4 {
                            Text("+\(exercises.count - 4)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Pulse.textTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Pulse.surfaceElevatedFallback)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .payaCard()
        }
        .buttonStyle(PulsePress())
        .onAppear {
            TrainingDayStore.seedIfNeeded(context: modelContext)
            todayDay = TrainingDayStore.today(context: modelContext)
            if let day = todayDay {
                let defs = CustomSessionStore.effectiveExercises(forCode: day.code, context: modelContext)
                exercises = defs.map(\.name)
            }
        }
    }

    private func shortName(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: " — ", with: " ")
            .replacingOccurrences(of: "°", with: "")
        let words = cleaned.split(separator: " ")
        if words.count <= 2 { return cleaned }
        return words.prefix(2).joined(separator: " ")
    }
}
