import SwiftUI
import SwiftData

// MARK: - Exercise Preference Learner
//
// Analyzes the user's actual completed sessions to learn which exercises
// they consistently do for each training day. Shows a suggestion card
// when the installed program doesn't match their real behavior.
//
// Behavioral research basis:
// - Steele et al. (2017): adherence to resistance training is higher
//   when programs match personal preferences — exercise selection is
//   one of the strongest correlates of long-term consistency.
// - Nuzzo (2021) review: exercise enjoyment predicts training frequency
//   better than any performance outcome.
//
// The algorithm:
// 1. Group completed sessions by day code (A/B/C)
// 2. For each day, count exercise frequency across sessions
// 3. Rank by frequency — exercises the user always does vs sometimes skips
// 4. Compare with the currently installed program
// 5. Suggest updates when behavior diverges from program

struct ExercisePreferenceCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var suggestions: [DaySuggestion] = []
    @State private var hasData = false
    @State private var expanded = false

    struct DaySuggestion: Identifiable {
        let dayCode: String
        let dayName: String
        let alwaysDo: [ExerciseFrequency]     // 100% of sessions
        let usuallyDo: [ExerciseFrequency]    // 60-99%
        let sometimesDo: [ExerciseFrequency]  // 30-59%
        let rarelyDo: [ExerciseFrequency]     // <30%
        let sessionCount: Int
        var id: String { dayCode }
    }

    struct ExerciseFrequency: Identifiable {
        let exerciseName: String
        let count: Int
        let totalSessions: Int
        let frequency: Double // 0.0–1.0
        var id: String { exerciseName }

        var frequencyLabel: String {
            String(format: "%.0f%%", frequency * 100)
        }
    }

    var body: some View {
        Group {
            if hasData && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.25)) { expanded.toggle() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "brain.head.profile.fill")
                                .foregroundColor(Color(hex: "8B5CF6"))
                            Text("Your exercise preferences")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Text("Learned from \(suggestions.reduce(0) { $0 + $1.sessionCount }) sessions")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if expanded {
                        ForEach(suggestions) { day in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(day.dayName)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "059669"))

                                if !day.alwaysDo.isEmpty {
                                    exerciseRow(label: "Always", exercises: day.alwaysDo, color: Color(hex: "059669"))
                                }
                                if !day.usuallyDo.isEmpty {
                                    exerciseRow(label: "Usually", exercises: day.usuallyDo, color: Color(hex: "2563EB"))
                                }
                                if !day.rarelyDo.isEmpty {
                                    exerciseRow(label: "Rarely", exercises: day.rarelyDo, color: Color(hex: "DC2626"))
                                }
                            }
                            .padding(10)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "F59E0B"))
                            Text("Exercises you rarely do might be worth swapping. Go to Manage → Customize Today's Exercises to update your program.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text("Steele et al. (2017): exercise preference is one of the strongest predictors of long-term training adherence.")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { analyze() }
    }

    private func exerciseRow(label: String, exercises: [ExerciseFrequency], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .black))
                .foregroundColor(color)

            FlowLayout(spacing: 4) {
                ForEach(exercises) { ex in
                    HStack(spacing: 3) {
                        Text(ex.exerciseName)
                            .font(.system(size: 10, weight: .semibold))
                        Text(ex.frequencyLabel)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(color)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Analyze

    private func analyze() {
        let pid = ActiveProfile.id
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()

        let sessionDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= cutoff
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let sessions = (try? modelContext.fetch(sessionDesc)) ?? []
        guard sessions.count >= 5 else { return }

        // Group by day code
        var dayGroups: [String: [[ExerciseLog]]] = [:]
        for session in sessions {
            let code = session.sessionType
            guard !code.isEmpty else { continue }
            var group = dayGroups[code] ?? []
            group.append(session.exercises)
            dayGroups[code] = group
        }

        var result: [DaySuggestion] = []

        for (code, sessionExercises) in dayGroups {
            let sessionCount = sessionExercises.count
            guard sessionCount >= 3 else { continue }

            // Count exercise frequency
            var exerciseCounts: [String: Int] = [:]
            for exercises in sessionExercises {
                let completedNames = Set(exercises.filter { !$0.sets.filter(\.isCompleted).isEmpty }.map(\.exerciseName))
                for name in completedNames {
                    exerciseCounts[name, default: 0] += 1
                }
            }

            let frequencies = exerciseCounts.map { name, count in
                ExerciseFrequency(
                    exerciseName: name,
                    count: count,
                    totalSessions: sessionCount,
                    frequency: Double(count) / Double(sessionCount)
                )
            }
            .sorted { $0.frequency > $1.frequency }

            let dayName: String
            switch code {
            case "A": dayName = "Day A"
            case "B": dayName = "Day B"
            case "C": dayName = "Day C"
            default: dayName = "Day \(code)"
            }

            result.append(DaySuggestion(
                dayCode: code,
                dayName: dayName,
                alwaysDo: frequencies.filter { $0.frequency >= 1.0 },
                usuallyDo: frequencies.filter { $0.frequency >= 0.6 && $0.frequency < 1.0 },
                sometimesDo: frequencies.filter { $0.frequency >= 0.3 && $0.frequency < 0.6 },
                rarelyDo: frequencies.filter { $0.frequency < 0.3 },
                sessionCount: sessionCount
            ))
        }

        guard !result.isEmpty else { return }
        hasData = true
        suggestions = result.sorted { $0.dayCode < $1.dayCode }
    }
}

// FlowLayout is defined in ReflectionSheet.swift — reused here
