import SwiftUI
import SwiftData

// MARK: - Calorie Deficit Engine
//
// Computes the live calorie balance (in vs out) and tracks a streak of
// consecutive days hitting the goal-appropriate target. The definition of
// "on target" depends on the training goal:
//   - Fat loss: deficit of 300-700 kcal (Helms ER, et al. "Evidence-based
//     recommendations for contest preparation." JISSN 2014 — recommends
//     ~500 kcal/day deficit for ~0.5-1% BW/week loss while preserving LBM)
//   - Hypertrophy: surplus of 200-500 kcal (Iraki J, et al. "Nutrition
//     recommendations for bodybuilders in the off-season." JISSN 2019)
//   - Maintenance/stayFit: within ±200 kcal of TDEE
//   - Strength: within ±300 kcal
//   - Endurance: within ±300 kcal

enum CalorieDeficitEngine {

    struct DayResult {
        let date: Date
        let caloriesIn: Double
        let caloriesOut: Double
        let balance: Double          // negative = deficit, positive = surplus
        let isOnTarget: Bool
        let targetDescription: String
    }

    struct StreakReport {
        let today: DayResult
        let streakDays: Int
        let last7Days: [DayResult]
    }

    @MainActor
    static func analyze(context: ModelContext, profile: UserProfile) -> StreakReport {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let pid = ActiveProfile.id

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        let nutDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.date >= weekAgo && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let nutritionLogs = (try? context.fetch(nutDescriptor)) ?? []

        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.date >= weekAgo && $0.profileId == pid && $0.isCompleted == true },
            sortBy: [SortDescriptor(\.date)]
        )
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []

        var results: [DayResult] = []

        for dayOffset in -6...0 {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            let dayLog = nutritionLogs.first { calendar.isDate($0.date, inSameDayAs: dayDate) }
            let caloriesIn = dayLog?.totalCalories ?? 0

            let bmr = TDEEEngine.bmr(
                bodyWeightKg: profile.currentWeightKg,
                age: profile.age,
                heightCm: profile.heightCm,
                sexRaw: profile.sexRaw
            )
            let daySessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: dayDate) }
            let trainingKcal = daySessions.reduce(0.0) { total, session in
                guard let avgHR = session.sessionAvgHR, avgHR > 0 else {
                    return total + Double(session.durationMinutes) * 5
                }
                return total + TDEEEngine.sessionActivityKcal(
                    avgHR: avgHR,
                    durationMinutes: session.durationMinutes,
                    bodyWeightKg: profile.currentWeightKg,
                    age: profile.age,
                    sexRaw: profile.sexRaw
                )
            }
            let neat = bmr * 0.2
            let caloriesOut = bmr + neat + trainingKcal
            let balance = caloriesIn - caloriesOut

            let (onTarget, targetDesc) = evaluateTarget(
                balance: balance,
                goal: profile.goal,
                caloriesIn: caloriesIn
            )

            results.append(DayResult(
                date: dayDate,
                caloriesIn: caloriesIn,
                caloriesOut: caloriesOut,
                balance: balance,
                isOnTarget: onTarget,
                targetDescription: targetDesc
            ))
        }

        let todayResult = results.last ?? DayResult(
            date: today, caloriesIn: 0, caloriesOut: 0,
            balance: 0, isOnTarget: false, targetDescription: ""
        )

        // Count streak backward from today
        var streak = 0
        for result in results.reversed() {
            guard result.isOnTarget && result.caloriesIn > 0 else { break }
            streak += 1
        }

        return StreakReport(today: todayResult, streakDays: streak, last7Days: results)
    }

    private static func evaluateTarget(balance: Double, goal: TrainingGoal, caloriesIn: Double) -> (Bool, String) {
        guard caloriesIn > 0 else {
            return (false, "No food logged yet")
        }

        switch goal {
        case .fatLoss:
            let isOn = balance < -200 && balance > -800
            return (isOn, "Target: 300-700 kcal deficit")
        case .hypertrophy:
            let isOn = balance > 100 && balance < 600
            return (isOn, "Target: 200-500 kcal surplus")
        case .strength:
            let isOn = abs(balance) < 400
            return (isOn, "Target: within ±300 kcal of TDEE")
        case .stayFit, .endurance:
            let isOn = abs(balance) < 300
            return (isOn, "Target: within ±200 kcal of TDEE")
        }
    }

    @MainActor
    static func scheduleEndOfDayNotification(context: ModelContext, profile: UserProfile) {
        let report = analyze(context: context, profile: profile)
        guard report.today.caloriesIn > 0 else { return }

        let title: String
        let body: String
        let balance = report.today.balance

        if report.today.isOnTarget {
            if report.streakDays > 1 {
                title = "\(report.streakDays)-day streak!"
                body = "You've hit your calorie target \(report.streakDays) days in a row. Balance: \(Int(balance)) kcal."
            } else {
                title = "On target today"
                body = "Calorie balance: \(Int(balance)) kcal — right where it should be for \(profile.goal.displayName.lowercased())."
            }
        } else {
            if balance > 0 {
                title = "Over target today"
                body = "You're \(Int(balance)) kcal over your estimated expenditure. \(report.today.targetDescription)."
            } else {
                title = "Deficit check"
                body = "Running a \(Int(abs(balance))) kcal deficit. \(report.today.targetDescription)."
            }
        }

        guard let pid = ActiveProfile.id else { return }
        let record = NotificationRecord(
            category: .meal,
            title: title,
            message: body,
            profileId: pid,
            destination: .nutrition,
            deduplicationKey: "calorie_eod_\(Calendar.current.startOfDay(for: .now).timeIntervalSince1970)"
        )
        _ = try? NotificationCenterStore.createIfNeeded(record, context: context)
    }
}

// MARK: - Calorie Deficit Card

struct CalorieDeficitCard: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var report: CalorieDeficitEngine.StreakReport?
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Calorie Balance")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Pulse.textPrimary)
                    Spacer()
                    if let report, report.streakDays > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text("\(report.streakDays)d streak")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Pulse.textTertiary)
                }

                if let report {
                    todayBalance(report.today)
                    weekBarChart(report)
                } else {
                    Text("Log food to see your balance")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }
            }
            .payaCard(padding: 14)
        }
        .buttonStyle(PulsePress())
        .onAppear { loadReport() }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in loadReport() }
        .sheet(isPresented: $showDetail) {
            if let report {
                CalorieDeficitDetailView(report: report, profile: appState.profile)
            }
        }
    }

    @ViewBuilder
    private func todayBalance(_ day: CalorieDeficitEngine.DayResult) -> some View {
        let bal = Int(day.balance)
        let inVal = Int(day.caloriesIn)
        let outVal = Int(day.caloriesOut)

        VStack(spacing: 10) {
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("\(inVal)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.positive)
                    Text("eaten")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                }
                .frame(maxWidth: .infinity)

                Text("−")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Pulse.textTertiary)

                VStack(spacing: 2) {
                    Text("\(outVal)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.critical)
                    Text("burned")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                }
                .frame(maxWidth: .infinity)

                Text("=")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Pulse.textTertiary)

                VStack(spacing: 2) {
                    Text(bal >= 0 ? "+\(bal)" : "\(bal)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(balanceColor(day))
                    Text(bal >= 0 ? "surplus" : "deficit")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }

            if inVal > 0 {
                GeometryReader { geo in
                    let frac = min(1.0, day.caloriesIn / max(1.0, day.caloriesOut))
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Pulse.surfaceElevatedFallback)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(balanceColor(day))
                            .frame(width: geo.size.width * frac, height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text(balanceInsight(day))
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                    Spacer()
                    Text(day.targetDescription)
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                }
            }
        }
    }

    private func balanceColor(_ day: CalorieDeficitEngine.DayResult) -> Color {
        guard day.caloriesIn > 0 else { return .secondary }
        if day.isOnTarget { return Pulse.positive }
        return day.balance > 0 ? Pulse.warning : Pulse.hydration
    }

    private func balanceInsight(_ day: CalorieDeficitEngine.DayResult) -> String {
        if day.caloriesIn == 0 { return "No food logged yet" }
        if day.isOnTarget { return "On track — within target range" }
        if day.balance > 300 { return "Over target — consider lighter next meal" }
        if day.balance > 0 { return "Slightly over — still close" }
        if day.balance < -500 { return "\(abs(Int(day.balance))) kcal room left today" }
        return "\(abs(Int(day.balance))) kcal room left today"
    }

    private func loadReport() {
        report = CalorieDeficitEngine.analyze(
            context: modelContext,
            profile: appState.profile
        )
    }

    @ViewBuilder
    private func weekBarChart(_ report: CalorieDeficitEngine.StreakReport) -> some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(report.last7Days, id: \.date) { day in
                VStack(spacing: 3) {
                    let maxAbs = report.last7Days.map { abs($0.balance) }.max() ?? 500
                    let barHeight = day.caloriesIn > 0 ? max(6, 32 * CGFloat(abs(day.balance) / max(1, maxAbs))) : 6

                    if day.caloriesIn > 0 {
                        Text(day.balance >= 0 ? "+\(Int(day.balance))" : "\(Int(day.balance))")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(barFill(day))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barFill(day))
                        .frame(height: barHeight)

                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Calendar.current.isDateInToday(day.date) ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barFill(_ day: CalorieDeficitEngine.DayResult) -> Color {
        guard day.caloriesIn > 0 else { return Pulse.surfaceElevatedFallback }
        if day.isOnTarget { return Pulse.positive }
        return day.balance > 0 ? Pulse.warning : Pulse.hydration
    }
}

// MARK: - Calorie Deficit Detail View

struct CalorieDeficitDetailView: View {

    @Environment(\.dismiss) private var dismiss
    let report: CalorieDeficitEngine.StreakReport
    let profile: UserProfile

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    todayBreakdown
                    streakSection
                    weekBreakdown
                    goalExplanation
                }
                .padding(16)
            }
            .navigationTitle("Calorie Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Today

    private var todayBreakdown: some View {
        let today = report.today
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(balanceColor(today).opacity(0.2), lineWidth: 8)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: today.caloriesIn > 0 ? min(1, today.caloriesIn / max(1, today.caloriesOut)) : 0)
                        .stroke(balanceColor(today), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int(today.balance))")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(balanceColor(today))
                        Text("kcal")
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.textTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(today.isOnTarget ? "On Target" : (today.caloriesIn > 0 ? "Off Target" : "No Food Logged"))
                        .font(.headline)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(Int(today.caloriesIn))")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Pulse.positive)
                            Text("Calories in")
                                .font(.system(size: 9))
                                .foregroundColor(Pulse.textTertiary)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(Int(today.caloriesOut))")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Pulse.critical)
                            Text("Calories out")
                                .font(.system(size: 9))
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }
                }
                Spacer()
            }

            if today.caloriesIn > 0 {
                Text(today.targetDescription)
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(balanceColor(today).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .payaCard(padding: 16)
    }

    // MARK: - Streak

    private var streakSection: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(report.streakDays)")
                        .font(.title2.weight(.bold))
                }
                Text("Day streak")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .payaCard(padding: 14)

            VStack(spacing: 4) {
                let onTarget = report.last7Days.filter { $0.isOnTarget }.count
                Text("\(onTarget)/7")
                    .font(.title2.weight(.bold))
                    .foregroundColor(onTarget >= 5 ? Pulse.positive : .primary)
                Text("Days on target")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .payaCard(padding: 14)
        }
    }

    // MARK: - Week Breakdown

    private var weekBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LAST 7 DAYS")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)

            ForEach(report.last7Days.reversed(), id: \.date) { day in
                HStack(spacing: 10) {
                    Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption.weight(.semibold))
                        .frame(width: 32, alignment: .leading)

                    GeometryReader { geo in
                        let w = geo.size.width
                        let maxAbs = report.last7Days.map { abs($0.balance) }.max() ?? 500
                        let barW = day.caloriesIn > 0 ? max(8, w * CGFloat(abs(day.balance) / max(1, maxAbs))) : 0
                        let isDeficit = day.balance < 0

                        ZStack(alignment: isDeficit ? .trailing : .leading) {
                            Color.clear
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barFill(day))
                                .frame(width: barW / 2, height: 16)
                                .offset(x: isDeficit ? -w / 2 + barW / 4 : w / 2 - barW / 4)
                        }
                    }
                    .frame(height: 16)

                    Text(day.caloriesIn > 0 ? "\(Int(day.balance))" : "—")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(barFill(day))
                        .frame(width: 44, alignment: .trailing)

                    if day.isOnTarget && day.caloriesIn > 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.positive)
                    } else {
                        Color.clear.frame(width: 10)
                    }
                }
                .frame(height: 20)
            }
        }
        .payaCard(padding: 14)
    }

    // MARK: - Goal Explanation

    private var goalExplanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHY THIS TARGET")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)

            let explanation: String = {
                switch profile.goal {
                case .fatLoss:
                    return "Your goal is fat loss. A deficit of 300-700 kcal/day targets ~0.5-1% bodyweight loss per week — the evidence-based range that preserves lean mass while losing fat (Helms ER, et al. JISSN 2014)."
                case .hypertrophy:
                    return "Your goal is muscle growth. A moderate surplus of 200-500 kcal/day provides the energy for new tissue synthesis without excessive fat gain (Iraki J, et al. JISSN 2019)."
                case .strength:
                    return "Your goal is strength. Staying within ±300 kcal of expenditure balances performance and body composition — enough fuel for hard sessions without drifting far from weight."
                case .stayFit, .endurance:
                    return "Your goal is maintenance. Staying within ±200 kcal of expenditure keeps weight stable while supporting daily activity and training recovery."
                }
            }()

            Text(explanation)
                .font(.caption)
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Pulse.surfaceElevatedFallback.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: PayaRadius.card))
    }

    // MARK: - Helpers

    private func balanceColor(_ day: CalorieDeficitEngine.DayResult) -> Color {
        guard day.caloriesIn > 0 else { return .secondary }
        if day.isOnTarget { return Pulse.positive }
        return day.balance > 0 ? Pulse.warning : Pulse.hydration
    }

    private func barFill(_ day: CalorieDeficitEngine.DayResult) -> Color {
        guard day.caloriesIn > 0 else { return Pulse.surfaceElevatedFallback }
        if day.isOnTarget { return Pulse.positive }
        return day.balance > 0 ? Pulse.warning : Pulse.hydration
    }
}
