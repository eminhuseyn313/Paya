import Foundation
import SwiftData

// MARK: - Daily Narrative Engine
//
// Phase 2 of the correlation/insight roadmap: a synthesis layer over the
// independent signal engines (flare risk, wellness correlation, allostatic
// load, digestive patterns, chrono-nutrition, glucose, cycle-aware). Each of
// those already computes real, well-grounded findings — but surfaced as N
// separate cards, they read as scattered observations, not one coherent
// picture. This engine doesn't replace any of them; it reads across their
// outputs and picks the ONE thing most worth leading with today, then ranks
// everything else as supporting context. Same "hero + everything else" shift
// already applied to Progress and Home — here at the data-synthesis level
// instead of the layout level.
//
// Deliberately does NOT recompute the heavy per-engine work if the caller
// already has it (flare assessment, wellness insights are normally already
// computed elsewhere on the same screen) — pass them in. The remaining
// engines (Allostasis/Digestive/Chrono/Glucose/Cycle) run concurrently via
// async let, same pattern already used in TrainViewModel, so this adds
// latency equal to the SLOWEST one of them, not the sum.

enum DailyNarrativeEngine {

    struct Narrative {
        let headline: Point
        let supporting: [Point]
        let sourceCount: Int

        struct Point: Identifiable {
            let id = UUID()
            let source: String
            let text: String
            let icon: String
            let colorHex: String
            /// Higher = more worth leading with. Not shown in UI — only
            /// used to pick the headline and sort supporting points.
            let priority: Int
        }
    }

    /// - Parameters:
    ///   - flareAssessment: pass the already-computed value if the caller has
    ///     one (e.g. DashboardViewModel) rather than recomputing.
    ///   - wellnessInsights: same — from `WellnessCorrelationEngine.analyzeToday`.
    static func build(
        context: ModelContext,
        sexRaw: String,
        flareAssessment: FlareRiskAssessment?,
        flareForecast: FlareForecastEngine.Forecast? = nil,
        wellnessInsights: [WellnessCorrelationEngine.Insight]
    ) async -> Narrative? {
        async let allostasis = AllostasisEngine.compute()
        async let digestive = DigestivePatternEngine.compute(context: context)
        async let chrono = ChronoNutritionEngine.compute(context: context)
        async let cycle = CycleAwareEngine.compute(sexRaw: sexRaw)

        let (allostasisReport, digestiveReport, chronoInsights, cycleOverview) =
            await (allostasis, digestive, chrono, cycle)

        var points: [Narrative.Point] = []
        var sourceCount = 0

        // Flare risk — highest ceiling priority since it's a direct
        // symptom-risk signal, not a background pattern.
        if let assessment = flareAssessment, assessment.level != .low {
            sourceCount += 1
            let severity = assessment.level == .high ? 95 : 80
            points.append(.init(
                source: "Flare risk",
                text: "\(assessment.level.rawValue) flare risk today — \(assessment.recommendation.components(separatedBy: ".").first ?? assessment.recommendation).",
                icon: "exclamationmark.triangle.fill",
                colorHex: assessment.level == .high ? "DC2626" : "D97706",
                priority: severity
            ))
        } else if let forecast = flareForecast, forecast.trajectory == .worsening {
            // Today looks fine but the leading indicator doesn't — this is
            // exactly the case a same-day-only assessment misses, so it
            // earns a high priority even though today's raw level is low.
            sourceCount += 1
            points.append(.init(
                source: "Flare forecast",
                text: forecast.summary,
                icon: "chart.line.uptrend.xyaxis",
                colorHex: "D97706",
                priority: 75
            ))
        }

        // Allostatic load — trajectory matters more than the raw score;
        // "rising for weeks" is the kind of thing a single day's cards miss.
        if let report = allostasisReport {
            sourceCount += 1
            if report.band == .elevated || report.band == .high {
                points.append(.init(
                    source: "Stress load",
                    text: "\(report.band.rawValue) stress load, \(report.trajectory.rawValue.lowercased()) over the last 2 weeks. \(report.recommendation)",
                    icon: "waveform.path.ecg.rectangle",
                    colorHex: report.band == .high ? "DC2626" : "D97706",
                    priority: report.band == .high ? 90 : 70
                ))
            } else if report.trajectory == .rising {
                points.append(.init(
                    source: "Stress load",
                    text: "Stress load is trending up, still \(report.band.rawValue.lowercased()) — worth watching before it compounds.",
                    icon: "arrow.up.right",
                    colorHex: "D97706",
                    priority: 40
                ))
            }
        }

        // Digestive pattern — a confirmed trigger is a directly actionable,
        // high-confidence finding.
        if let report = digestiveReport, let topTrigger = report.topTriggers.first {
            sourceCount += 1
            points.append(.init(
                source: "Digestion",
                text: "\(topTrigger.label) preceded a bad outcome \(Int(topTrigger.badOutcomeRate * 100))% of the time (\(topTrigger.occurrences) occurrences tracked).",
                icon: "fork.knife.circle.fill",
                colorHex: "D97706",
                priority: 55
            ))
        }

        // Chrono-nutrition — only surface strong-confidence findings here;
        // moderate/emerging ones stay in their own card, not important
        // enough yet to lead the day's story.
        if let topChrono = chronoInsights.first(where: { $0.confidence == .strong }) {
            sourceCount += 1
            points.append(.init(
                source: topChrono.category.rawValue,
                text: "\(topChrono.headline) — \(topChrono.detail)",
                icon: "clock.fill",
                colorHex: topChrono.metricColor == .negative ? "D97706" : "059669",
                priority: 45
            ))
        }

        // Jet lag — no new data source (just the device's own timezone
        // history), but a real explanation for "why does my readiness look
        // confusingly off" that nothing else in the app could surface.
        // Fairly high priority while active: it's the kind of context that,
        // if missing, makes every OTHER signal below harder to interpret.
        if let jetLag = JetLagDetector.checkAndRecord() {
            sourceCount += 1
            points.append(.init(
                source: "Travel",
                text: jetLag.summary,
                icon: "airplane",
                colorHex: jetLag.isEasingOff ? "059669" : "D97706",
                priority: jetLag.isEasingOff ? 25 : 55
            ))
        }

        // Cycle-aware — only when there's an actual phase-specific
        // recommendation, not just "no data."
        if cycleOverview.isAvailable, let topRec = cycleOverview.recommendations.first {
            sourceCount += 1
            points.append(.init(
                source: "Cycle phase",
                text: "\(topRec.title) — \(topRec.detail)",
                icon: "moon.stars.fill",
                colorHex: "8B5CF6",
                priority: 35
            ))
        }

        // Public holiday — Nager.Date, free, no key. Low priority (never
        // the day's headline on its own) but valuable as context in the
        // trend journal: "this rough week included a holiday" explains a
        // routine dip instead of it looking unexplained weeks later.
        if let holidayName = await PublicHolidayService.todaysHolidayName() {
            sourceCount += 1
            points.append(.init(
                source: "Calendar",
                text: "Today is \(holidayName) — routine (training, meals, sleep timing) commonly shifts on holidays.",
                icon: "calendar.badge.clock",
                colorHex: "8B5CF6",
                priority: 15
            ))
        }

        // Wellness correlation — background signal, lowest default
        // priority since it's same-day pattern-matching, not a trend.
        if let topWellness = wellnessInsights.first {
            sourceCount += 1
            points.append(.init(
                source: "Today's pattern",
                text: topWellness.text,
                icon: topWellness.icon,
                colorHex: topWellness.colorHex,
                priority: 30
            ))
        }

        guard !points.isEmpty else { return nil }
        let sorted = points.sorted { $0.priority > $1.priority }
        return Narrative(
            headline: sorted[0],
            supporting: Array(sorted.dropFirst()),
            sourceCount: sourceCount
        )
    }
}
