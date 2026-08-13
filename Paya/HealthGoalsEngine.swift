import Foundation
import SwiftData

// MARK: - Health Goals Engine
// Computes streaks and adherence from HealthLog history for gamification.

enum HealthGoalsEngine {

    struct Report {
        let supplementStreakDays: Int       // consecutive days with 100% supplements
        let checkInStreakDays: Int          // consecutive days with any health log
        let weekSupplementAdherence: Double // 0-1 over last 7 days
        let weekSleepGoalNights: Int        // nights with >= 7h in last 7 days
        let weekCheckIns: Int               // days with a log in last 7 days

        var badge: Badge? {
            if supplementStreakDays >= 30 { return .gold }
            if supplementStreakDays >= 14 { return .silver }
            if supplementStreakDays >= 7 { return .bronze }
            return nil
        }
    }

    enum Badge {
        case bronze, silver, gold

        var label: String {
            switch self {
            case .bronze: return "7-day streak"
            case .silver: return "14-day streak"
            case .gold:   return "30-day streak"
            }
        }

        var icon: String {
            switch self {
            case .bronze: return "medal"
            case .silver: return "medal.fill"
            case .gold:   return "crown.fill"
            }
        }

        var colorHex: String {
            switch self {
            case .bronze: return "B45309"
            case .silver: return "6B7280"
            case .gold:   return "D97706"
            }
        }
    }

    static func compute(
        logs: [HealthLog],
        activeSupplementCount: Int
    ) -> Report {
        let calendar = Calendar.current
        let byDay: [String: HealthLog] = Dictionary(
            logs.map { (dayKey($0.date), $0) },
            uniquingKeysWith: { a, _ in a }
        )

        // Supplement streak: consecutive days ending today or yesterday
        var supplementStreak = 0
        var cursor = Date()
        // Allow streak to be alive if today isn't complete yet: start from yesterday if today incomplete
        if !isSupplementComplete(byDay[dayKey(cursor)], target: activeSupplementCount) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while isSupplementComplete(byDay[dayKey(cursor)], target: activeSupplementCount) {
            supplementStreak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        // Check-in streak
        var checkInStreak = 0
        cursor = Date()
        if byDay[dayKey(cursor)] == nil {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while byDay[dayKey(cursor)] != nil {
            checkInStreak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        // Last-7-days stats
        var adherenceSum = 0.0
        var sleepNights = 0
        var checkIns = 0
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            if let log = byDay[dayKey(day)] {
                checkIns += 1
                if activeSupplementCount > 0 {
                    adherenceSum += min(1.0, Double(log.supplementsTaken.count) / Double(activeSupplementCount))
                }
                if log.sleepHours >= 7.0 {
                                    sleepNights += 1
                                }
            }
        }

        return Report(
            supplementStreakDays: supplementStreak,
            checkInStreakDays: checkInStreak,
            weekSupplementAdherence: adherenceSum / 7.0,
            weekSleepGoalNights: sleepNights,
            weekCheckIns: checkIns
        )
    }

    private static func isSupplementComplete(_ log: HealthLog?, target: Int) -> Bool {
        guard target > 0, let log = log else { return false }
        return log.supplementsTaken.count >= target
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }
}//
//  HealthGoalsEngine.swift
//  Paya
//
//  Created by Emin Huseynzade on 11.07.26.
//

