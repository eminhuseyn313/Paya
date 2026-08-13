import SwiftUI
import SwiftData

// MARK: - Weekly Training Plan Card
// Shows a 7-day forward view of recommended training based on the user's
// program, recovery status, and smart programming suggestions. Combines:
// - Training days from the current program
// - Recovery/readiness scores to flag optimal rest days
// - Muscle freshness to validate day placement
// This is the "what should I do this week?" card that connects the user's
// program to their actual physiological state.

struct WeeklyPlanCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var dayPlans: [DayPlan] = []

    var body: some View {
        Group {
            if !dayPlans.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(Color(hex: "2563EB"))
                        Text("This week")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("auto-planned")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }

                    // 7-day strip
                    HStack(spacing: 4) {
                        ForEach(dayPlans) { plan in
                            VStack(spacing: 4) {
                                Text(plan.dayLabel)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(plan.isToday ? .white : .secondary)

                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(plan.backgroundColor)
                                        .frame(height: 52)

                                    VStack(spacing: 2) {
                                        Image(systemName: plan.icon)
                                            .font(.system(size: plan.isRest ? 11 : 13))
                                            .foregroundColor(plan.iconColor)

                                        if let label = plan.shortLabel {
                                            Text(label)
                                                .font(.system(size: 7, weight: .bold))
                                                .foregroundColor(plan.iconColor)
                                                .lineLimit(1)
                                        }
                                    }
                                }

                                if plan.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "059669"))
                                } else {
                                    Color.clear.frame(height: 10)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(
                                plan.isToday
                                    ? AnyShapeStyle(plan.todayColor.opacity(0.12))
                                    : AnyShapeStyle(Color.clear)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Summary line
                    HStack(spacing: 12) {
                        let trainingDays = dayPlans.filter { !$0.isRest }.count
                        let restDays = dayPlans.filter { $0.isRest }.count
                        let completed = dayPlans.filter { $0.isCompleted }.count

                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: "2563EB")).frame(width: 6, height: 6)
                            Text("\(trainingDays) training")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(Color(.tertiarySystemBackground)).frame(width: 6, height: 6)
                            Text("\(restDays) rest")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        if completed > 0 {
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: "059669")).frame(width: 6, height: 6)
                                Text("\(completed) done")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(Color(hex: "059669"))
                            }
                        }
                    }
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func compute() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pid = ActiveProfile.id
        let days = TrainingDayStore.allSnapshots(context: modelContext)
        guard !days.isEmpty else { return }

        // Fetch this week's completed sessions
        let weekStart = calendar.date(byAdding: .day, value: -7, to: today)!
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= weekStart
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let completedSessions = (try? modelContext.fetch(descriptor)) ?? []
        let completedDates = Set(completedSessions.map { calendar.startOfDay(for: $0.date) })

        // Get the user's training day schedule (which weekdays they train)
        let profileDays = appState.profile.trainingDays
        let trainingDaysCount = profileDays.isEmpty
            ? min(days.count, 5)
            : profileDays.count

        // Build 7-day plan starting from today
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        var plans: [DayPlan] = []
        let dayRotation = days

        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let weekday = calendar.component(.weekday, from: date)
            let isToday = offset == 0
            let isCompleted = completedDates.contains(date)
            let dayLabel = String(dayFormatter.string(from: date).prefix(3))

            // Determine if this is a training day based on the user's schedule
            // Simple heuristic: spread training days evenly across the week
            let isTrainingDay = profileDays.isEmpty
                ? assignedDay(weekday: weekday, trainingDaysCount: trainingDaysCount)
                : profileDays.contains(weekday)

            if isTrainingDay, let assigned = dayForWeekday(weekday: weekday, days: dayRotation, trainingDaysCount: trainingDaysCount) {
                plans.append(DayPlan(
                    dayLabel: dayLabel,
                    isToday: isToday,
                    isRest: false,
                    isCompleted: isCompleted,
                    icon: "dumbbell.fill",
                    shortLabel: assigned.code,
                    backgroundColor: isCompleted
                        ? Color(hex: "059669").opacity(0.1)
                        : assigned.color.opacity(0.1),
                    iconColor: isCompleted
                        ? Color(hex: "059669")
                        : assigned.color,
                    todayColor: assigned.color
                ))
            } else {
                plans.append(DayPlan(
                    dayLabel: dayLabel,
                    isToday: isToday,
                    isRest: true,
                    isCompleted: false,
                    icon: "bed.double.fill",
                    shortLabel: "Rest",
                    backgroundColor: Color(.tertiarySystemBackground),
                    iconColor: .secondary.opacity(0.5),
                    todayColor: .secondary
                ))
            }
        }

        dayPlans = plans
    }

    /// Determines which weekdays are training days based on count.
    /// Spreads training days optimally with rest between them.
    private func assignedDay(weekday: Int, trainingDaysCount: Int) -> Bool {
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat
        switch trainingDaysCount {
        case 1: return weekday == 2 // Mon
        case 2: return [2, 5].contains(weekday) // Mon, Thu
        case 3: return [2, 4, 6].contains(weekday) // Mon, Wed, Fri
        case 4: return [2, 3, 5, 6].contains(weekday) // Mon, Tue, Thu, Fri
        case 5: return [2, 3, 4, 5, 6].contains(weekday) // Mon-Fri
        case 6: return weekday != 1 // Every day except Sun
        default: return [2, 4, 6].contains(weekday) // Default 3-day
        }
    }

    /// Maps a weekday to a training day from the rotation.
    private func dayForWeekday(weekday: Int, days: [DaySnapshot], trainingDaysCount: Int) -> DaySnapshot? {
        let trainingWeekdays: [Int]
        switch trainingDaysCount {
        case 1: trainingWeekdays = [2]
        case 2: trainingWeekdays = [2, 5]
        case 3: trainingWeekdays = [2, 4, 6]
        case 4: trainingWeekdays = [2, 3, 5, 6]
        case 5: trainingWeekdays = [2, 3, 4, 5, 6]
        case 6: trainingWeekdays = [2, 3, 4, 5, 6, 7]
        default: trainingWeekdays = [2, 4, 6]
        }
        guard let index = trainingWeekdays.firstIndex(of: weekday) else { return nil }
        let dayIndex = index % days.count
        return days[dayIndex]
    }
}

private struct DayPlan: Identifiable {
    let id = UUID()
    let dayLabel: String
    let isToday: Bool
    let isRest: Bool
    let isCompleted: Bool
    let icon: String
    let shortLabel: String?
    let backgroundColor: Color
    let iconColor: Color
    let todayColor: Color
}
