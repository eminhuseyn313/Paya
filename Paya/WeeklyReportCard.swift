import SwiftUI
import SwiftData

// MARK: - Weekly Report Card
// A comprehensive A–F graded summary of the past 7 days across all pillars:
// Training, Nutrition, Recovery, and Consistency. Like getting a school
// report card for your fitness week.

struct WeeklyReportCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var report: WeeklyReport? = nil
    @State private var expanded = false

    var body: some View {
        Group {
            if let report = report {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(Pulse.hydration)
                        Text("Weekly Report")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        overallGradeBadge(report.overallGrade)
                    }

                    HStack(spacing: 8) {
                        gradeColumn(title: "Train", grade: report.trainingGrade, icon: "dumbbell.fill", color: "059669")
                        gradeColumn(title: "Nutrition", grade: report.nutritionGrade, icon: "fork.knife", color: "F59E0B")
                        gradeColumn(title: "Recovery", grade: report.recoveryGrade, icon: "bed.double.fill", color: "8B5CF6")
                        gradeColumn(title: "Consistency", grade: report.consistencyGrade, icon: "calendar", color: "2563EB")
                    }

                    if expanded {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(report.highlights, id: \.self) { highlight in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Pulse.positive)
                                        .padding(.top, 1)
                                    Text(highlight)
                                        .font(.system(size: 10))
                                        .foregroundColor(Pulse.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            if !report.improvements.isEmpty {
                                ForEach(report.improvements, id: \.self) { improvement in
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "arrow.up.circle")
                                            .font(.system(size: 10))
                                            .foregroundColor(Pulse.nutrition)
                                            .padding(.top, 1)
                                        Text(improvement)
                                            .font(.system(size: 10))
                                            .foregroundColor(Pulse.textPrimary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    } label: {
                        Text(expanded ? "Show less" : "See details")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Pulse.hydration)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PulsePress())
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func overallGradeBadge(_ grade: String) -> some View {
        Text(grade)
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(colorForGrade(grade))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func gradeColumn(title: String, grade: String, icon: String, color: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: color))
            Text(grade)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(colorForGrade(grade))
            Text(title)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(colorForGrade(grade).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func colorForGrade(_ grade: String) -> Color {
        switch grade {
        case "A+", "A": return Pulse.positive
        case "A-", "B+", "B": return Pulse.hydration
        case "B-", "C+", "C": return Pulse.nutrition
        case "C-", "D+", "D": return Pulse.critical
        default: return .secondary
        }
    }

    private func compute() {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let pid = ActiveProfile.id

        let sDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.date >= weekAgo }
        )
        let weekSessions = ((try? modelContext.fetch(sDescriptor)) ?? []).filter(\.isCompleted)

        let nDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid && $0.date >= weekAgo }
        )
        let weekNutrition = (try? modelContext.fetch(nDescriptor)) ?? []

        let hDescriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid && $0.date >= weekAgo }
        )
        let weekHealth = (try? modelContext.fetch(hDescriptor)) ?? []

        // Training grade
        let targetSessions = appState.profile.trainingDays.count
        let sessionCount = weekSessions.count
        let trainingRatio = targetSessions > 0 ? Double(sessionCount) / Double(targetSessions) : 0
        let trainingGrade = gradeFromRatio(trainingRatio)

        // Nutrition grade
        let proteinHitDays = weekNutrition.filter { $0.totalProtein >= $0.proteinTarget * 0.9 }.count
        let calorieHitDays = weekNutrition.filter {
            let target = $0.calorieTarget
            return $0.totalCalories >= target * 0.9 && $0.totalCalories <= target * 1.1
        }.count
        let loggedDays = weekNutrition.count
        let nutritionRatio = loggedDays > 0
            ? (Double(proteinHitDays) + Double(calorieHitDays)) / (Double(loggedDays) * 2)
            : 0
        let nutritionGrade = loggedDays == 0 ? "N/A" : gradeFromRatio(nutritionRatio)

        // Recovery grade
        let avgSleep = weekHealth.isEmpty ? 0 : weekHealth.map(\.sleepHours).reduce(0, +) / Double(weekHealth.count)
        let flareDays = weekHealth.filter(\.isFlareDay).count
        let recoveryRatio: Double
        if weekHealth.isEmpty {
            recoveryRatio = 0.5
        } else {
            let sleepScore = min(1, avgSleep / 8)
            let flareScore = max(0, 1 - Double(flareDays) / 7)
            recoveryRatio = (sleepScore + flareScore) / 2
        }
        let recoveryGrade = weekHealth.isEmpty ? "N/A" : gradeFromRatio(recoveryRatio)

        // Consistency grade
        let uniqueDays = Set(weekSessions.map { calendar.startOfDay(for: $0.date) }).count
        let restDays = 7 - uniqueDays
        let hadRestDay = restDays >= 1
        let spreadScore = Double(uniqueDays) / Double(max(1, targetSessions))
        let consistencyRatio = min(1, (spreadScore + (hadRestDay ? 0.2 : 0)) / 1.2)
        let consistencyGrade = gradeFromRatio(consistencyRatio)

        // Overall
        let grades = [trainingGrade, nutritionGrade, consistencyGrade, recoveryGrade].filter { $0 != "N/A" }
        let gradeValues = grades.map(gradeToNumber)
        let avgGrade = gradeValues.isEmpty ? 0.0 : gradeValues.reduce(0, +) / Double(gradeValues.count)
        let overallGrade = numberToGrade(avgGrade)

        // Highlights & improvements
        var highlights: [String] = []
        var improvements: [String] = []

        if sessionCount >= targetSessions {
            highlights.append("Hit your \(targetSessions)-session target this week")
        } else if sessionCount > 0 {
            improvements.append("Trained \(sessionCount)/\(targetSessions) planned sessions")
        }

        if proteinHitDays >= 5 {
            highlights.append("Hit protein target \(proteinHitDays) out of \(loggedDays) days")
        } else if proteinHitDays < 3 && loggedDays > 0 {
            improvements.append("Protein target hit only \(proteinHitDays)/\(loggedDays) days — try meal prep")
        }

        if avgSleep >= 7.5 && !weekHealth.isEmpty {
            highlights.append(String(format: "Averaged %.1f hours sleep — solid recovery", avgSleep))
        } else if avgSleep < 7 && avgSleep > 0 {
            improvements.append(String(format: "Sleep averaged %.1f hrs — aim for 7.5+ for recovery", avgSleep))
        }

        if flareDays == 0 && !weekHealth.isEmpty {
            highlights.append("Zero flare days — great week")
        } else if flareDays >= 3 {
            improvements.append("\(flareDays) flare days — consider lowering training volume")
        }

        let totalVolume = weekSessions.reduce(0.0) { total, session in
            total + session.exercises.reduce(0.0) { t, ex in
                t + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            }
        }
        if totalVolume > 0 {
            let vol = appState.profile.prefersLbs ? totalVolume * 2.20462 : totalVolume
            let unit = appState.profile.prefersLbs ? "lbs" : "kg"
            highlights.append(String(format: "Total volume: %.0f %@", vol, unit))
        }

        report = WeeklyReport(
            trainingGrade: trainingGrade,
            nutritionGrade: nutritionGrade,
            recoveryGrade: recoveryGrade,
            consistencyGrade: consistencyGrade,
            overallGrade: overallGrade,
            highlights: highlights,
            improvements: improvements
        )
    }

    private func gradeFromRatio(_ ratio: Double) -> String {
        switch ratio {
        case 0.95...: return "A+"
        case 0.9..<0.95: return "A"
        case 0.85..<0.9: return "A-"
        case 0.8..<0.85: return "B+"
        case 0.7..<0.8: return "B"
        case 0.6..<0.7: return "B-"
        case 0.5..<0.6: return "C+"
        case 0.4..<0.5: return "C"
        case 0.3..<0.4: return "C-"
        case 0.2..<0.3: return "D+"
        default: return "D"
        }
    }

    private func gradeToNumber(_ grade: String) -> Double {
        switch grade {
        case "A+": return 4.3
        case "A": return 4.0
        case "A-": return 3.7
        case "B+": return 3.3
        case "B": return 3.0
        case "B-": return 2.7
        case "C+": return 2.3
        case "C": return 2.0
        case "C-": return 1.7
        case "D+": return 1.3
        case "D": return 1.0
        default: return 0
        }
    }

    private func numberToGrade(_ num: Double) -> String {
        switch num {
        case 4.15...: return "A+"
        case 3.85..<4.15: return "A"
        case 3.5..<3.85: return "A-"
        case 3.15..<3.5: return "B+"
        case 2.85..<3.15: return "B"
        case 2.5..<2.85: return "B-"
        case 2.15..<2.5: return "C+"
        case 1.85..<2.15: return "C"
        case 1.5..<1.85: return "C-"
        case 1.15..<1.5: return "D+"
        default: return "D"
        }
    }
}

private struct WeeklyReport {
    let trainingGrade: String
    let nutritionGrade: String
    let recoveryGrade: String
    let consistencyGrade: String
    let overallGrade: String
    let highlights: [String]
    let improvements: [String]
}
