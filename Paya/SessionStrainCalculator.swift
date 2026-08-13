import Foundation

/// Pure-function calculator for session HR analytics.
/// TRIMP uses Banister's method with male exponential weighting (0.64 × e^(1.92 × HRR)).
enum SessionStrainCalculator {

    struct StrainReport {
        let peakHR: Int?
        let avgHR: Int?
        let trimpScore: Double
        let timeInZoneSeconds: [Int]   // [Z1, Z2, Z3, Z4, Z5]
        let totalActiveSeconds: Int

        var strainLabel: String {
            switch Int(trimpScore) {
            case 0..<30:    return "Light"
            case 30..<60:   return "Moderate"
            case 60..<90:   return "Hard"
            case 90..<120:  return "Very Hard"
            default:        return "Maximum"
            }
        }

        var strainColorHex: String {
            switch Int(trimpScore) {
            case 0..<30:    return "60A5FA"
            case 30..<60:   return "10B981"
            case 60..<90:   return "FBBF24"
            case 90..<120:  return "F97316"
            default:        return "DC2626"
            }
        }
    }

    static func computeStrain(
        hrSamples: [Int],
        intervalSeconds: Int = 5,
        maxHR: Int,
        restingHR: Int = 60
    ) -> StrainReport {

        let validSamples = hrSamples.filter { $0 > 0 }
        guard !validSamples.isEmpty else {
            return StrainReport(
                peakHR: nil,
                avgHR: nil,
                trimpScore: 0,
                timeInZoneSeconds: [0, 0, 0, 0, 0],
                totalActiveSeconds: 0
            )
        }

        let peakHR = validSamples.max()
        let avgHR = validSamples.reduce(0, +) / validSamples.count
        let hrReserve = Double(max(1, maxHR - restingHR))

        var trimp = 0.0
        var zoneSeconds = [0, 0, 0, 0, 0]
        let intervalMinutes = Double(intervalSeconds) / 60.0

        for bpm in validSamples {
            let hrr = max(0, min(1, Double(bpm - restingHR) / hrReserve))
            let weight = 0.64 * exp(1.92 * hrr)
            trimp += intervalMinutes * hrr * weight

            let percent = Double(bpm) / Double(maxHR)
            let zoneIndex: Int
            switch percent {
            case 0.90...:      zoneIndex = 4
            case 0.80..<0.90:  zoneIndex = 3
            case 0.70..<0.80:  zoneIndex = 2
            case 0.60..<0.70:  zoneIndex = 1
            case 0.50..<0.60:  zoneIndex = 0
            default:           zoneIndex = -1
            }
            if zoneIndex >= 0 {
                zoneSeconds[zoneIndex] += intervalSeconds
            }
        }

        return StrainReport(
            peakHR: peakHR,
            avgHR: avgHR,
            trimpScore: trimp,
            timeInZoneSeconds: zoneSeconds,
            totalActiveSeconds: validSamples.count * intervalSeconds
        )
    }

    static func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Heart-rate recovery (HRR60)

    /// bpm drop 60 seconds after the session's final effort peak — one of the
    /// strongest single cardio-fitness/autonomic markers a strap can produce
    /// (Cole et al.: slow recovery predicts poor outcomes; ≥25 is well-trained).
    /// Uses the buffer tail that keeps sampling while the completion sheet is
    /// open. Returns nil unless a full 60s post-peak window exists and the
    /// drop is genuinely positive (a negative drop means the "peak" wasn't
    /// actually exercise cessation).
    static func hrRecovery60(samples: [Int], intervalSeconds: Int = 5) -> Int? {
        guard intervalSeconds > 0 else { return nil }
        let samplesPerMinute = 60 / intervalSeconds
        guard samples.count > samplesPerMinute else { return nil }

        // Look for the peak within the final 5 minutes that still has a full
        // 60s of samples after it.
        let windowStart = max(0, samples.count - samplesPerMinute * 5)
        let eligibleEnd = samples.count - samplesPerMinute
        guard windowStart < eligibleEnd else { return nil }

        var peakIdx = windowStart
        for i in windowStart..<eligibleEnd where samples[i] > samples[peakIdx] {
            peakIdx = i
        }

        let drop = samples[peakIdx] - samples[peakIdx + samplesPerMinute]
        return drop > 0 ? drop : nil
    }
}
