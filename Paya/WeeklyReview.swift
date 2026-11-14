import SwiftUI
import SwiftData

// MARK: - Weekly review
// A short "how did my week go" summary: this week vs the one before, built only
// from what you logged and what your watch measured. Nothing is invented: a
// metric with too little data is left out rather than shown as zero.

struct WeeklyReview {
    struct Row: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let value: String
        let detail: String?       // e.g. "+1 vs last week"
        let color: Color
    }
    struct Note: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
        let color: Color
    }

    var rangeText: String
    var headline: String
    var rows: [Row]
    var notes: [Note]
    var hasAnyData: Bool
}

@MainActor
enum WeeklyReviewEngine {

    static func build(context: ModelContext, profile: UserProfile, flareTracked: Bool) -> WeeklyReview {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now)) ?? .now
        let thisStart = cal.date(byAdding: .day, value: -7, to: end) ?? end
        let prevStart = cal.date(byAdding: .day, value: -14, to: end) ?? end
        let pid = ActiveProfile.id
        var rows: [WeeklyReview.Row] = []
        var notes: [WeeklyReview.Note] = []

        // ── Training ────────────────────────────────────────────────
        let sessions = (try? context.fetch(FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.profileId == pid && $0.isCompleted == true && $0.date >= prevStart }
        ))) ?? []
        let thisSessions = sessions.filter { $0.date >= thisStart }
        let prevSessions = sessions.filter { $0.date < thisStart }
        func volume(_ s: [TrainingSession]) -> Double {
            s.reduce(0) { acc, session in
                acc + session.exercises.reduce(0) { a, ex in
                    a + ex.sets.filter(\.isCompleted).reduce(0) { $0 + $1.weightKg * Double($1.reps) }
                }
            }
        }
        let vol = volume(thisSessions)
        if !thisSessions.isEmpty || !prevSessions.isEmpty {
            rows.append(.init(
                icon: "dumbbell.fill", title: "Training",
                value: "\(thisSessions.count) session\(thisSessions.count == 1 ? "" : "s")",
                detail: delta(thisSessions.count, prevSessions.count, unit: "", suffix: " vs last week"),
                color: Pulse.energy))
            if vol > 0 {
                let useLbs = profile.prefersLbs
                let shown = vol * (useLbs ? 2.20462 : 1)
                rows.append(.init(
                    icon: "scalemass.fill", title: "Weight lifted",
                    value: "\(Int(shown).formatted()) \(useLbs ? "lb" : "kg")",
                    detail: volume(prevSessions) > 0 ? delta(Int(vol), Int(volume(prevSessions)), unit: "", suffix: " vs last week", percent: true) : nil,
                    color: Pulse.recovery))
            }
        }
        if thisSessions.isEmpty {
            notes.append(.init(icon: "figure.walk", text: "No workouts logged this week. Even a short session keeps the habit going.", color: Pulse.warning))
        }

        // ── Nutrition ───────────────────────────────────────────────
        let logs = (try? context.fetch(FetchDescriptor<NutritionLog>(
            predicate: #Predicate { $0.profileId == pid && $0.date >= thisStart }
        ))) ?? []
        let logged = logs.filter { $0.totalCalories > 0 }
        if !logged.isEmpty {
            let proteinDays = logged.filter { $0.proteinTarget > 0 && $0.totalProtein >= 0.9 * $0.proteinTarget }.count
            rows.append(.init(
                icon: "fork.knife", title: "Protein target",
                value: "\(proteinDays) of \(logged.count) logged days",
                detail: "Food logged on \(logged.count) of 7 days",
                color: Pulse.positive))
            if proteinDays < max(1, logged.count / 2) {
                notes.append(.init(icon: "fork.knife", text: "Protein was on target on fewer than half of your logged days.", color: Pulse.warning))
            }
        } else {
            notes.append(.init(icon: "fork.knife", text: "No meals logged this week, so there's no nutrition summary.", color: Pulse.textSecondary))
        }

        // ── Sleep & HRV (Apple Watch / Health) ──────────────────────
        let history = BiometricStore.shared.history
        func avg(_ pick: (DailySummary) -> Double?, from: Date, to: Date) -> (Double, Int)? {
            let vals = history.filter { $0.date >= from && $0.date < to }.compactMap(pick)
            guard vals.count >= 3 else { return nil }   // need at least 3 nights/readings
            return (vals.reduce(0, +) / Double(vals.count), vals.count)
        }
        if let (sleep, n) = avg({ $0.sleepHours }, from: thisStart, to: end) {
            let prev = avg({ $0.sleepHours }, from: prevStart, to: thisStart)?.0
            rows.append(.init(
                icon: "moon.fill", title: "Sleep",
                value: String(format: "%.1f h avg", sleep),
                detail: prev.map { String(format: "%+.1f h vs last week", sleep - $0) } ?? "\(n) nights",
                color: Pulse.ai))
            if sleep < 7 {
                notes.append(.init(icon: "moon.zzz.fill", text: String(format: "Sleep averaged %.1f h, under the 7 h or more that sleep-medicine guidance recommends for adults.", sleep), color: Pulse.warning))
            }
        }
        if let (hrv, _) = avg({ $0.hrv }, from: thisStart, to: end) {
            let prev = avg({ $0.hrv }, from: prevStart, to: thisStart)?.0
            rows.append(.init(
                icon: "waveform.path.ecg", title: "HRV",
                value: "\(Int(hrv.rounded())) ms avg",
                detail: prev.map { "\(Int((hrv - $0).rounded()) >= 0 ? "+" : "")\(Int((hrv - $0).rounded())) ms vs last week" },
                color: Pulse.recovery))
        }

        // ── Weight ──────────────────────────────────────────────────
        let weights = (try? context.fetch(FetchDescriptor<BodyWeightLog>(
            predicate: #Predicate { $0.profileId == pid && $0.date >= prevStart },
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []
        if let latest = weights.last(where: { $0.date >= thisStart }),
           let before = weights.last(where: { $0.date < thisStart }) {
            let d = latest.weightKg - before.weightKg
            let useLbs = profile.prefersLbs
            rows.append(.init(
                icon: "scalemass", title: "Weight",
                value: String(format: "%.1f %@", latest.weightKg * (useLbs ? 2.20462 : 1), useLbs ? "lb" : "kg"),
                detail: String(format: "%+.1f %@ vs last week", d * (useLbs ? 2.20462 : 1), useLbs ? "lb" : "kg"),
                color: Pulse.hydration))
        }

        // ── Flare days (only when the user tracks a condition) ──────
        if flareTracked {
            let days = (try? context.fetch(FetchDescriptor<HealthLog>(
                predicate: #Predicate { $0.profileId == pid && $0.date >= thisStart && $0.isFlareDay == true }
            ))) ?? []
            rows.append(.init(
                icon: "exclamationmark.triangle.fill", title: "Flare days you logged",
                value: "\(days.count)", detail: nil, color: Pulse.warning))
        }

        let fmt = Date.FormatStyle().month(.abbreviated).day()
        let range = "\(thisStart.formatted(fmt)) – \(cal.date(byAdding: .day, value: -1, to: end)!.formatted(fmt))"
        let headline: String
        if thisSessions.isEmpty && logged.isEmpty && rows.isEmpty {
            headline = "Not enough logged this week"
        } else if thisSessions.count >= 3 {
            headline = "A solid training week"
        } else if thisSessions.isEmpty {
            headline = "A quiet week"
        } else {
            headline = "You kept moving"
        }
        return WeeklyReview(rangeText: range, headline: headline, rows: rows, notes: notes, hasAnyData: !rows.isEmpty)
    }

    private static func delta(_ now: Int, _ before: Int, unit: String, suffix: String, percent: Bool = false) -> String {
        if percent {
            guard before > 0 else { return "" }
            let p = Int((Double(now - before) / Double(before) * 100).rounded())
            return "\(p >= 0 ? "+" : "")\(p)%\(suffix)"
        }
        let d = now - before
        return "\(d >= 0 ? "+" : "")\(d)\(unit)\(suffix)"
    }

    // "Seen" tracking so Sunday's prompt shows once per week.
    private static func weekKey() -> String {
        let c = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return "weekly_review_seen_\(c.yearForWeekOfYear ?? 0)_\(c.weekOfYear ?? 0)"
    }
    static var seenThisWeek: Bool { UserDefaults.standard.bool(forKey: weekKey()) }
    static func markSeen() { UserDefaults.standard.set(true, forKey: weekKey()) }

    /// Sunday from 5 pm: surface the review as Home's next action once.
    static var isDue: Bool {
        let c = Calendar.current.dateComponents([.weekday, .hour], from: .now)
        return c.weekday == 1 && (c.hour ?? 0) >= 17 && !seenThisWeek
    }
}

// MARK: - Screen

struct WeeklyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var review: WeeklyReview?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR WEEK")
                            .font(.pulse(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(Pulse.textSecondary)
                        Text(review?.rangeText ?? "")
                            .font(.pulse(size: 13))
                            .foregroundColor(Pulse.textTertiary)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.pulse(size: 22))
                            .foregroundColor(Pulse.textTertiary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                }

                if let r = review {
                    Text(r.headline)
                        .font(.pulse(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)

                    if r.hasAnyData {
                        VStack(spacing: 10) {
                            ForEach(r.rows) { row in
                                HStack(spacing: 12) {
                                    Image(systemName: row.icon)
                                        .font(.pulse(size: 16, weight: .semibold))
                                        .foregroundColor(row.color)
                                        .frame(width: 34, height: 34)
                                        .background(Circle().fill(row.color.opacity(0.15)))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.title).font(.pulse(size: 13)).foregroundColor(Pulse.textSecondary)
                                        Text(row.value).font(.pulse(size: 17, weight: .bold, design: .rounded)).foregroundColor(Pulse.textPrimary)
                                    }
                                    Spacer()
                                    if let d = row.detail, !d.isEmpty {
                                        Text(d).font(.pulse(size: 12)).foregroundColor(Pulse.textSecondary).multilineTextAlignment(.trailing)
                                    }
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: Pulse.Radius.sm).fill(Pulse.surfaceFallback))
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }

                    if !r.notes.isEmpty {
                        Text("WORTH A LOOK")
                            .font(.pulse(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(Pulse.textSecondary)
                            .padding(.top, 4)
                        ForEach(r.notes) { n in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: n.icon).foregroundColor(n.color).frame(width: 22)
                                Text(n.text).font(.pulse(size: 15)).foregroundColor(Pulse.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Text("Built only from what you logged and what your Apple Watch measured. Metrics with too little data are left out, not guessed. This is a wellness summary, not medical advice.")
                        .font(.pulse(size: 12))
                        .foregroundColor(Pulse.textTertiary)
                        .padding(.top, 6)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(20)
        }
        .background(Pulse.canvasFallback.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task {
            if BiometricStore.shared.history.isEmpty { await BiometricStore.shared.loadHistory(daysBack: 30) }
            review = WeeklyReviewEngine.build(context: modelContext, profile: appState.profile, flareTracked: appState.flareEngineEnabled)
            WeeklyReviewEngine.markSeen()
        }
    }
}

// MARK: - Home card

struct WeeklyReviewCard: View {
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "calendar.badge.clock")
                    .font(.pulse(size: 22))
                    .foregroundColor(Pulse.recovery)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Pulse.recovery.opacity(0.15)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your week in review")
                        .font(.pulse(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                    Text("Training, nutrition, sleep and more vs last week")
                        .font(.pulse(size: 13))
                        .foregroundColor(Pulse.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(Pulse.textTertiary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Pulse.Radius.md).fill(Pulse.surfaceFallback))
        }
        .buttonStyle(PulsePress())
        .accessibilityHint("Opens a summary of your last 7 days")
    }
}
