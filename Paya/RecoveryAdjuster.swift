import Foundation
import SwiftUI

// MARK: - Recovery Context
// Snapshot of the user's readiness signals for today.

struct RecoveryContext {
    let recoveryScore: Int?           // 0-100, or nil if HealthKit unavailable
    let sleepHours: Double?           // last night sleep from HealthKit
    let flareLevel: FlareRiskLevel?   // FlareDetectionEngine assessment
    let isFlareDay: Bool              // user-tagged flare day
    let yesterdayTrimp: Double?
    let chronicAvgDailyTrimp: Double?   // trailing 28-day daily average — the ACWR "chronic" baseline
    let restingHR: Int?// yesterday's session strain
    let isDeloadWeek: Bool

    static let empty = RecoveryContext(
            recoveryScore: nil,
            sleepHours: nil,
            flareLevel: nil,
            isFlareDay: false,
            yesterdayTrimp: nil,
            chronicAvgDailyTrimp: nil,
            restingHR: nil,
            isDeloadWeek: false

        )

    var hasAnySignal: Bool {
        recoveryScore != nil
            || sleepHours != nil
            || flareLevel != nil
            || isFlareDay
            || yesterdayTrimp != nil
    }
}

// MARK: - Recovery Adjuster
//
// On research grounding for the specific percentages below: there is no
// single published formula that converts "readiness score" or "flare risk"
// into "reduce today's working weight by X%" — this is the same territory
// WHOOP's Recovery/Strain scoring and Oura's Readiness Score operate in.
// Both are HRV/RHR/sleep-baseline-relative composites (like ReadinessEngine
// here) feeding an undisclosed, proprietary mapping to a training
// recommendation; neither publishes the exact multiplier their "take it
// easy today" recommendation applies. So the multipliers below are
// deliberately documented as engineering judgment anchored to real
// principles, not dressed up as a cited formula they aren't:
//   - RPE-based autoregulation (Helms et al., the "RPE/RIR" load-adjustment
//     approach used in evidence-based programming) supports the general
//     idea that a poor-recovery day should train at a lower relative
//     intensity, not skip training — hence adjustments here scale load
//     down, they never zero it out.
//   - The 25% total-reduction cap exists so a bad day never compounds into
//     an accidental deload from stacked multipliers (e.g. flare + poor
//     sleep + low recovery all firing at once) — the floor is a safety
//     rail, not a research-derived number.
//   - The deload-week cut (35%) is the one number closest to a citable
//     source: Israetel/RP deload guidance describes cutting volume/intensity
//     meaningfully (~40-50% is common RP guidance for volume specifically)
//     for one week every 4-6 weeks; this app expresses that as a straight
//     weight cut rather than a volume cut, so treat the exact percentage as
//     inspired by that guidance, not a direct implementation of it.
//   - Flare day (25% cut) and elevated/high predicted flare risk (10%/20%
//     cuts) are RA-context-specific judgment calls, not from a sports-
//     science source — there's no published "how much lighter should an RA
//     patient train on a flare day" study; this is a conservative, safety-
//     first design choice.
// These numbers are intentionally easy to find and adjust here if real
// user outcomes suggest they're off — that's the point of writing this out
// rather than leaving five bare Doubles with no explanation.

enum RecoveryAdjuster {

    struct Adjustment {
        let originalWeight: Double
        let adjustedWeight: Double
        let multiplier: Double
        let reasons: [Reason]
        let severity: Severity

        var reductionPercent: Int {
            Int((1.0 - multiplier) * 100)
        }

        /// Signed, display-ready percent: "+2" for a progression nudge, "-10" for a cut.
        var signedPercentLabel: String {
            let pct = Int(((multiplier - 1.0) * 100).rounded())
            return pct >= 0 ? "+\(pct)%" : "\(pct)%"
        }

        var isAdjusted: Bool {
            severity != .normal || multiplier != 1.0
        }
    }

    struct Reason: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
    }

    enum Severity {
        case normal
        case caution
        case deload

        var color: Color {
            switch self {
            case .normal:  return Color(hex: "059669")
            case .caution: return Color(hex: "B45309")
            case .deload:  return Color(hex: "DC2626")
            }
        }

        var label: String {
            switch self {
            case .normal:  return "Normal loads"
            case .caution: return "Modest reduction"
            case .deload:  return "Deload day"
            }
        }

        var icon: String {
            switch self {
            case .normal:  return "checkmark.circle.fill"
            case .caution: return "arrow.down.circle.fill"
            case .deload:  return "exclamationmark.arrow.circlepath"
            }
        }
    }

    // MARK: - Compute

    static func compute(
        baseWeight: Double,
        context: RecoveryContext
    ) -> Adjustment {

        var multiplier = 1.0
        var reasons: [Reason] = []

        // Flare day is absolute — takes precedence, other signals ignored.
        // 25% cut: conservative safety-first judgment call for training
        // through an active RA flare, not a cited clinical threshold.
                if context.isFlareDay {
                    multiplier = 0.75
                    reasons.append(Reason(
                        icon: "flame.fill",
                        text: "Flare day active"
                    ))
                } else if context.isDeloadWeek {
                    // 35% cut — inspired by RP/Israetel deload guidance
                    // (~40-50% volume reduction is their typical figure);
                    // expressed here as a straight weight cut rather than a
                    // volume cut, so treat as directionally aligned, not a
                    // literal implementation of that guidance.
                    multiplier = 0.65
                    reasons.append(Reason(
                        icon: "arrow.down.circle",
                        text: "Deload week — intentionally light"
                    ))
                } else {
                    
            // Predicted flare risk — RA-context judgment calls (no
            // published "how much lighter to train pre-flare" study exists);
            // scaled so "high" predicted risk cuts roughly twice as much as
            // "elevated", matching the qualitative risk gap between the two
            // FlareDetectionEngine bands.
            if let flare = context.flareLevel {
                switch flare {
                case .high:
                    multiplier *= 0.80
                    reasons.append(Reason(
                        icon: "exclamationmark.triangle.fill",
                        text: "High flare risk detected"
                    ))
                case .elevated:
                    multiplier *= 0.90
                    reasons.append(Reason(
                        icon: "exclamationmark.triangle",
                        text: "Elevated flare risk"
                    ))
                default:
                    break
                }
            }

            // Recovery score — bands mirror ReadinessEngine.Band, and the
            // adjustment direction (autoregulate load down as recovery
            // drops, nudge up when primed) follows RPE/RIR-based
            // autoregulation principles (Helms et al.); the exact
            // percentages per band (2% up, then flat, then 5%/10%/15% down)
            // are a judgment call about how much of a "primed" or "poor"
            // day should actually move the weight on the bar, same as
            // WHOOP/Oura's undisclosed recovery-to-recommendation mapping.
            if let score = context.recoveryScore {
                switch score {
                case 90...100:
                    multiplier *= 1.02
                    reasons.append(Reason(
                        icon: "bolt.fill",
                        text: "Primed (\(score)/100) — small progression nudge"
                    ))
                case 85..<90:
                    break // great recovery, no adjustment
                case 70..<85:
                    break // normal, no adjustment
                case 55..<70:
                    multiplier *= 0.95
                    reasons.append(Reason(
                        icon: "heart.text.square",
                        text: "Moderate recovery (\(score)/100)"
                    ))
                case 40..<55:
                    multiplier *= 0.90
                    reasons.append(Reason(
                        icon: "heart.text.square",
                        text: "Low recovery (\(score)/100)"
                    ))
                default:
                    multiplier *= 0.85
                    reasons.append(Reason(
                        icon: "heart.text.square.fill",
                        text: "Poor recovery (\(score)/100)"
                    ))
                }
            }

            // Sleep debt — cutoffs approximate acute sleep-deprivation
            // performance literature (strength/power output measurably
            // drops below ~5-6h; more severe below ~4h), but the exact
            // 0.93/0.85 multipliers mapped to those cutoffs are ours, not
            // sourced from a specific study's effect size.
            if let sleep = context.sleepHours {
                if sleep < 4 {
                    multiplier *= 0.85
                    reasons.append(Reason(
                        icon: "moon.zzz.fill",
                        text: String(format: "Only %.1fh sleep last night", sleep)
                    ))
                } else if sleep < 5.5 {
                    multiplier *= 0.93
                    reasons.append(Reason(
                        icon: "moon.zzz",
                        text: String(format: "Short sleep: %.1fh", sleep)
                    ))
                }
            }

            // Heavy session yesterday — acute:chronic workload ratio
            // (Gabbett et al.): yesterday's TRIMP vs. this person's own
            // trailing 28-day daily average, not a fixed number that means
            // something different for a beginner vs. an advanced lifter.
            // ACWR > 1.5 is the commonly cited "danger zone" associated with
            // elevated injury/overreaching risk in the sports-science
            // literature; the 5%/8% cuts past that point are still ours —
            // Gabbett's work establishes the ratio threshold, not a
            // specific load-adjustment percentage.
            if let trimp = context.yesterdayTrimp, let chronicAvg = context.chronicAvgDailyTrimp, chronicAvg > 0 {
                let acwr = trimp / chronicAvg
                if acwr > 2.0 {
                    multiplier *= 0.92
                    reasons.append(Reason(
                        icon: "flame",
                        text: "Yesterday was ~\(Int(acwr * 100))% of your recent daily average — well above your norm"
                    ))
                } else if acwr > 1.5 {
                    multiplier *= 0.95
                    reasons.append(Reason(
                        icon: "flame",
                        text: "Heavier than usual yesterday (TRIMP \(Int(trimp)))"
                    ))
                }
            }
        }

        // Cap total reduction at 25%
        multiplier = max(0.75, multiplier)

        let adjustedRaw = baseWeight * multiplier
        let adjustedRounded = adjustedRaw.rounded(toNearest: 1.25)

        let severity: Severity
        if multiplier >= 0.98 {
            severity = .normal
        } else if multiplier >= 0.90 {
            severity = .caution
        } else {
            severity = .deload
        }

        return Adjustment(
            originalWeight: baseWeight,
            adjustedWeight: adjustedRounded,
            multiplier: multiplier,
            reasons: reasons,
            severity: severity
        )
    }
    
}//
//  RecoveryAdjuster.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//

