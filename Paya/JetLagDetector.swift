import Foundation

// MARK: - Jet Lag Detector
//
// No new API — just tracking the device's own timezone over time and
// noticing when it jumps. Circadian disruption from crossing time zones is
// well-established (Eastman CI, Burgess HJ. "How To Travel the World
// Without Jet Lag." Sleep Med Clin. 2009 — the circadian clock re-entrains
// at roughly 1 hour/day for eastward travel, slightly faster westward), so
// a sudden multi-hour offset change is a real, actionable context for why
// readiness/flare-forecast might look confusingly off for the next few
// days, not a mysterious dip.

enum JetLagDetector {

    private static let offsetKey = "jetlag_last_known_offset_seconds"
    private static let recordedAtKey = "jetlag_last_known_recorded_at"
    private static let shiftHoursKey = "jetlag_last_shift_hours"

    struct Status {
        let hoursShifted: Int
        let daysSinceShift: Int
        /// Rough re-entrainment estimate — ~1 day per hour crossed,
        /// clamped so it doesn't imply an absurdly long adjustment for a
        /// large shift.
        let expectedAdjustmentDays: Int
        var isEasingOff: Bool { daysSinceShift >= expectedAdjustmentDays }

        var summary: String {
            let direction = hoursShifted > 0 ? "ahead" : "behind"
            if isEasingOff {
                return "You crossed \(abs(hoursShifted)) time zone\(abs(hoursShifted) == 1 ? "" : "s") \(daysSinceShift) days ago — should be mostly adjusted by now."
            }
            let remaining = max(1, expectedAdjustmentDays - daysSinceShift)
            return "You crossed \(abs(hoursShifted)) time zone\(abs(hoursShifted) == 1 ? "" : "s") (\(direction)) \(daysSinceShift) day\(daysSinceShift == 1 ? "" : "s") ago — expect readiness and sleep to still be catching up for about \(remaining) more day\(remaining == 1 ? "" : "s")."
        }
    }

    /// Call once per day (e.g. alongside the daily briefing computation).
    /// Compares the current timezone offset against the last recorded one;
    /// if they differ by 2+ hours, records the new offset with today's date
    /// as the shift's start. Returns the active shift's status if one
    /// happened within the last 10 days (long enough to matter, short
    /// enough that showing it forever would be noise).
    static func checkAndRecord() -> Status? {
        let currentOffset = TimeZone.current.secondsFromGMT()
        let defaults = UserDefaults.standard
        let storedOffset = defaults.object(forKey: offsetKey) as? Int
        let storedDate = defaults.object(forKey: recordedAtKey) as? Date

        let hoursDiff = storedOffset.map { (currentOffset - $0) / 3600 } ?? 0

        if storedOffset == nil {
            // First run ever — just record the baseline, nothing to report.
            defaults.set(currentOffset, forKey: offsetKey)
            defaults.set(Date(), forKey: recordedAtKey)
            return nil
        }

        if abs(hoursDiff) >= 2 {
            // A genuine timezone change since the last check — this becomes
            // the new baseline and the new "shift start" date. Store the
            // shift size separately since `offsetKey` becomes the new
            // baseline immediately, overwriting the value we'd need to
            // compute hoursDiff again on a later day where nothing changed.
            defaults.set(currentOffset, forKey: offsetKey)
            defaults.set(Date(), forKey: recordedAtKey)
            defaults.set(hoursDiff, forKey: shiftHoursKey)
            return Status(hoursShifted: hoursDiff, daysSinceShift: 0, expectedAdjustmentDays: min(abs(hoursDiff), 7))
        }

        // No new change — but still report an active, recent shift so the
        // context persists for a few days after crossing, not just the
        // moment it happens.
        guard let storedDate else { return nil }
        let daysSince = Calendar.current.dateComponents([.day], from: storedDate, to: .now).day ?? 0
        guard daysSince <= 10 else { return nil }
        guard let lastShiftHours = defaults.object(forKey: shiftHoursKey) as? Int, lastShiftHours != 0 else { return nil }
        return Status(hoursShifted: lastShiftHours, daysSinceShift: daysSince, expectedAdjustmentDays: min(abs(lastShiftHours), 7))
    }
}
