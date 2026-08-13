import Foundation
import SwiftData

// MARK: - Readiness Engine
// Pre-workout readiness score, computed the way the readiness literature
// (and WHOOP/Oura in practice) says to: each biometric is scored against
// the USER'S OWN rolling baseline (z-score vs 30-day history), not against
// population thresholds. HRV carries the most weight; resting HR is
// inverted (elevated = suppressed recovery); sleep blends absolute hours
// with personal norm; yesterday's training load adds a fatigue penalty.
//
// Replaces the old absolute-threshold recovery score on the dashboard when
// enough history exists, and degrades gracefully to fewer components when
// data is sparse.
//
// On the exact component weights (HRV 40% / RHR 25% / sleep 25% / load 10%
// / check-in 15%): the baseline-relative (z-score) METHODOLOGY is the
// well-established part — it's what WHOOP's Recovery score and Oura's
// Readiness score are both built on, and HRV-as-dominant-signal is
// consistent with autonomic-nervous-system recovery research (HRV reflects
// parasympathetic reactivation faster and more sensitively than resting HR
// alone). But neither WHOOP nor Oura publishes their exact per-component
// weights — those are undisclosed proprietary tuning, not public formulas —
// so there is no citable source to match these percentages against. They're
// a defensible ordering (HRV > RHR ≈ sleep > everything else) rather than a
// derived constant, and the code renormalizes by total weight present, so
// they're relative importance, not literal percentage points. If real
// outcome data (e.g. does a "Steady" day actually correlate with a good
// session) surfaces a better ordering, these are the numbers to revisit.

enum ReadinessEngine {

    struct Driver: Identifiable {
        let id: String
        let label: String        // "HRV", "Resting HR", …
        let score: Double        // 0–100 for this component
        let detail: String       // "42ms · above your norm"
    }

    struct Report {
        let score: Int           // 0–100 composite
        let band: Band
        let drivers: [Driver]
        let recommendation: String
        let journeyNotes: [String]   // plain-language synthesis across biometrics + subjective check-in
    }

    enum Band: String {
        case primed = "Primed"
        case steady = "Steady"
        case caution = "Go easier"
        case recover = "Recovery day"

        var colorHex: String {
            switch self {
            case .primed:  return "059669"
            case .steady:  return "84CC16"
            case .caution: return "F59E0B"
            case .recover: return "DC2626"
            }
        }
    }

    /// z-score → 0–100 component score. Baseline (z=0) lands at 72 —
    /// "normal for you" is good, not neutral. ±1σ swings ~16 points.
    private static func scoreFromZ(_ z: Double) -> Double {
        min(100, max(0, 72 + 16 * z))
    }

    /// Absolute sleep-hours score anchored to the National Sleep Foundation's
    /// adult recommendation (7-9h optimal for ages 18-64), not an arbitrary
    /// "8h = 100%" ratio — 6h and 10h score the same distance from optimal,
    /// and the tail-off is gentler than a hard cutoff.
    private static func sleepAbsoluteScore(hours: Double) -> Double {
        switch hours {
        case 7...9:
            return 100
        case 6..<7:
            return 75 + (hours - 6) * 25
        case 9..<10:
            return 100 - (hours - 9) * 25
        default:
            let distance = hours < 7 ? (7 - hours) : (hours - 9)
            return max(30, 75 - distance * 15)
        }
    }

    @MainActor
    static func compute(store: BiometricStore, context: ModelContext) -> Report? {
        var weighted: [(score: Double, weight: Double)] = []
        var drivers: [Driver] = []

        // 1. HRV vs personal baseline — dominant signal (40%)
        if let z = store.zScoreToday(for: .hrv), let today = store.today?.hrv {
            let s = scoreFromZ(z)
            weighted.append((s, 0.40))
            drivers.append(Driver(
                id: "hrv", label: "HRV", score: s,
                detail: String(format: "%.0fms · %@", today, trendWord(z: z, higherIsBetter: true))
            ))
        }

        // 2. Resting HR vs baseline — inverted (25%)
        if let z = store.zScoreToday(for: .restingHR), let today = store.today?.restingHR {
            let s = scoreFromZ(-z)
            weighted.append((s, 0.25))
            drivers.append(Driver(
                id: "rhr", label: "Resting HR", score: s,
                detail: String(format: "%.0fbpm · %@", today, trendWord(z: z, higherIsBetter: false))
            ))
        }

        // 3. Sleep — absolute hours blended with personal norm (25%)
        if let hours = store.today?.sleepHours ?? store.yesterday?.sleepHours {
            let absolute = sleepAbsoluteScore(hours: hours)
            let relative = store.zScoreToday(for: .sleepHours).map(scoreFromZ)
            let s = relative.map { ($0 + absolute) / 2 } ?? absolute
            weighted.append((s, 0.25))
            drivers.append(Driver(
                id: "sleep", label: "Sleep", score: s,
                detail: String(format: "%.1fh last night", hours)
            ))
        }

        // 4. Yesterday's training load vs 7-day average — fatigue carry-over (10%)
        if let loadScore = yesterdayLoadScore(context: context) {
            weighted.append((loadScore.score, 0.10))
            drivers.append(Driver(
                id: "load", label: "Training load", score: loadScore.score,
                detail: loadScore.detail
            ))
        }

        // 5. This morning's subjective check-in — the "how do you feel"
        // signal biometrics alone can't see (soreness, energy, symptoms).
        let checkIn = todaysCheckIn(context: context)
        if let checkIn {
            let sorenessScore = scoreFromSoreness(checkIn.soreness)
            weighted.append((sorenessScore, 0.15))
            drivers.append(Driver(
                id: "checkin", label: "How you feel", score: sorenessScore,
                detail: sorenessDetail(checkIn.soreness, energy: checkIn.energy)
            ))
        }

        guard !weighted.isEmpty else { return nil }
        let totalWeight = weighted.reduce(0) { $0 + $1.weight }
        let composite = weighted.reduce(0) { $0 + $1.score * $1.weight } / totalWeight
        var score = Int(composite.rounded())

        // A flagged symptom overrides the number the same way a coach would
        // react to "I feel awful" over a good reading on a screen — it caps
        // the band rather than getting diluted into a single weighted average.
        let hasSymptomFlag = checkIn.map { !$0.symptomTags.isEmpty } ?? false
        if hasSymptomFlag {
            score = min(score, 55)
        }

        let band: Band
        switch score {
        case 80...: band = .primed
        case 60..<80: band = .steady
        case 40..<60: band = .caution
        default: band = .recover
        }

        let sortedDrivers = drivers.sorted { $0.score < $1.score }
        return Report(
            score: score,
            band: band,
            drivers: sortedDrivers,
            recommendation: recommendation(band: band, drivers: drivers),
            journeyNotes: journeyNotes(band: band, drivers: sortedDrivers, checkIn: checkIn, hasSymptomFlag: hasSymptomFlag)
        )
    }

    // MARK: - Daily check-in

    @MainActor
    private static func todaysCheckIn(context: ModelContext) -> DailyCheckIn? {
        let pid = ActiveProfile.id
        let start = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate { $0.date >= start && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.first
    }

    /// 1 (no soreness) scores best; 5 (very sore) scores worst.
    private static func scoreFromSoreness(_ soreness: Int) -> Double {
        switch soreness {
        case 1: return 92
        case 2: return 78
        case 3: return 60
        case 4: return 40
        default: return 20
        }
    }

    private static func sorenessDetail(_ soreness: Int, energy: Int) -> String {
        let sorenessWord = ["", "fresh", "a little tight", "noticeably sore", "quite sore", "very sore"][min(soreness, 5)]
        let energyWord = ["", "drained", "okay", "great"][min(max(energy, 0), 3)]
        return "Feeling \(sorenessWord) · energy \(energyWord)"
    }

    /// Synthesizes biometrics + subjective input into short, plain-language
    /// lines — the "journey" explanation rather than a bare number, tying
    /// what the watch measured to what the user actually reported feeling.
    private static func journeyNotes(band: Band, drivers: [Driver], checkIn: DailyCheckIn?, hasSymptomFlag: Bool) -> [String] {
        var notes: [String] = []

        if hasSymptomFlag, let checkIn {
            let names = checkIn.symptomTags
                .map { $0.replacingOccurrences(of: "_", with: " ") }
                .joined(separator: ", ")
            notes.append("You flagged \(names) this morning — today's plan leans on gentler alternatives regardless of what your biometrics show.")
        }

        if let hrv = drivers.first(where: { $0.id == "hrv" }), let checkIn {
            if hrv.score < 55 && checkIn.soreness >= 4 {
                notes.append("Your HRV is below your norm and you're reporting real soreness — both signals agree, this is a genuine recovery day.")
            } else if hrv.score >= 70 && checkIn.soreness >= 4 {
                notes.append("Your HRV looks normal but you're feeling sore — how you feel matters as much as the numbers, so this still counts.")
            } else if hrv.score < 55 && checkIn.soreness <= 2 {
                notes.append("Your HRV is suppressed even though you feel fine — worth going easier today; subjective feel can lag objective recovery.")
            }
        }

        if let load = drivers.first(where: { $0.id == "load" }), load.score < 50 {
            notes.append("Yesterday's session was harder than your typical week — today's readiness reflects that carry-over fatigue.")
        }

        if notes.isEmpty {
            switch band {
            case .primed: notes.append("Everything you've logged — biometrics and how you feel — points the same direction: good day to push.")
            case .steady: notes.append("Nothing in your data or check-in is flagging concern — a normal training day.")
            case .caution: notes.append("Something's a little off today — not a red flag, just a reason to ease the intensity slightly.")
            case .recover: notes.append("Multiple signals are pointing to fatigue — today is better spent recovering than pushing.")
            }
        }

        return notes
    }

    // MARK: - Components

    /// Yesterday's TRIMP vs the trailing 7-day daily average: training hard
    /// yesterday costs some readiness today; a rest day restores it.
    @MainActor
    private static func yesterdayLoadScore(context: ModelContext) -> (score: Double, detail: String)? {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.isCompleted == true && $0.date >= weekAgo && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        guard !sessions.isEmpty else { return nil }

        let weekTrimp = sessions.reduce(0.0) { $0 + ($1.sessionTrimpScore ?? 0) }
        let dailyAvg = weekTrimp / 7.0

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return nil }
        let yesterdayTrimp = sessions
            .filter { calendar.isDate($0.date, inSameDayAs: yesterday) }
            .reduce(0.0) { $0 + ($1.sessionTrimpScore ?? 0) }

        if yesterdayTrimp == 0 {
            return (85, "Rest day yesterday")
        }
        guard dailyAvg > 0 else { return nil }
        let ratio = yesterdayTrimp / max(dailyAvg, 1)
        // ratio 1 (typical day) → 70; 2× typical → 50; 3×+ → 30 floor
        let score = min(100, max(30, 90 - ratio * 20))
        return (score, String(format: "TRIMP %.0f yesterday", yesterdayTrimp))
    }

    // MARK: - Copy

    private static func trendWord(z: Double, higherIsBetter: Bool) -> String {
        let good = higherIsBetter ? z : -z
        switch good {
        case 0.5...: return "above your norm"
        case -0.5..<0.5: return "at your norm"
        default: return "below your norm"
        }
    }

    private static func recommendation(band: Band, drivers: [Driver]) -> String {
        let weakest = drivers.min { $0.score < $1.score }
        switch band {
        case .primed:
            return "Green light — a good day to push for progression."
        case .steady:
            return "Train as planned. Nothing is holding you back."
        case .caution:
            if let weakest {
                return "\(weakest.label) is dragging today — keep the session, drop intensity a notch (RPE −1)."
            }
            return "Slightly suppressed — keep the session, drop intensity a notch."
        case .recover:
            if let weakest {
                return "\(weakest.label) is well below your norm. Light movement beats a hard session today."
            }
            return "Your body is asking for a break — light movement only."
        }
    }
}
