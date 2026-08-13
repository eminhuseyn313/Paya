import Foundation
import SwiftData

// MARK: - Session Trends Calculator
// Pure functions for turning session history into trend data.

enum SessionTrendsCalculator {
    
    // MARK: - TRIMP Timeline
    
    struct DailyTrimpPoint: Identifiable {
        let id = UUID()
        let date: Date
        let trimp: Double
        let sessionType: String?
    }
    
    static func trimpTimeline(
        sessions: [TrainingSession],
        daysBack: Int = 30
    ) -> [DailyTrimpPoint] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -daysBack, to: Date())
        ?? Date()
        
        return sessions
            .filter { $0.date >= cutoff && $0.isCompleted }
            .compactMap { session -> DailyTrimpPoint? in
                guard let trimp = session.sessionTrimpScore, trimp > 0 else {
                    return nil
                }
                return DailyTrimpPoint(
                    date: session.date,
                    trimp: trimp,
                    sessionType: session.sessionType
                )
            }
            .sorted { $0.date < $1.date }
    }
    
    // MARK: - Session Type Baselines
    
    struct SessionTypeBaseline: Identifiable {
        let id = UUID()
        let sessionType: String
        let avgTrimp: Double
        let avgVolume: Double
        let avgDurationMin: Double
        let count: Int
        let lastTrimp: Double?
    }
    
    static func baselines(sessions: [TrainingSession]) -> [SessionTypeBaseline] {
        let completed = sessions.filter { $0.isCompleted }
        let grouped = Dictionary(grouping: completed) { $0.sessionType }
        
        var result: [SessionTypeBaseline] = []
        
        for type in ["A", "B", "C"] {
            let typeSessions = grouped[type] ?? []
            guard !typeSessions.isEmpty else {
                result.append(SessionTypeBaseline(
                    sessionType: type,
                    avgTrimp: 0,
                    avgVolume: 0,
                    avgDurationMin: 0,
                    count: 0,
                    lastTrimp: nil
                ))
                continue
            }
            
            let trimps = typeSessions.compactMap { $0.sessionTrimpScore }
            let avgTrimp = trimps.isEmpty
            ? 0
            : trimps.reduce(0, +) / Double(trimps.count)
            
            let volumes = typeSessions.map { Self.totalVolume(for: $0) }
            let avgVolume = volumes.reduce(0, +) / Double(volumes.count)
            
            let durations = typeSessions.map { Double($0.durationMinutes) }
            let avgDuration = durations.reduce(0, +) / Double(durations.count)
            
            let lastTrimp = typeSessions
                .sorted { $0.date > $1.date }
                .first?
                .sessionTrimpScore
            
            result.append(SessionTypeBaseline(
                sessionType: type,
                avgTrimp: avgTrimp,
                avgVolume: avgVolume,
                avgDurationMin: avgDuration,
                count: typeSessions.count,
                lastTrimp: lastTrimp
            ))
        }
        
        return result
    }
    
    // MARK: - Weekly Load
    
    struct WeeklyLoad: Identifiable {
        let id = UUID()
        let weekStartDate: Date
        let totalTrimp: Double
        let sessionCount: Int
        let label: String
    }
    
    static func weeklyLoad(
        sessions: [TrainingSession],
        weeksBack: Int = 6
    ) -> [WeeklyLoad] {
        let calendar = Calendar.current
        let now = Date()
        var result: [WeeklyLoad] = []
        
        for weekOffset in 0..<weeksBack {
            let weekStart = calendar.date(
                byAdding: .weekOfYear,
                value: -weekOffset,
                to: Self.startOfWeek(for: now)
            ) ?? now
            let weekEnd = calendar.date(
                byAdding: .day,
                value: 7,
                to: weekStart
            ) ?? weekStart
            
            let weekSessions = sessions.filter {
                $0.isCompleted
                && $0.date >= weekStart
                && $0.date < weekEnd
            }
            
            let totalTrimp = weekSessions
                .compactMap { $0.sessionTrimpScore }
                .reduce(0, +)
            
            let label: String
            switch weekOffset {
            case 0:  label = "This week"
            case 1:  label = "Last week"
            default: label = "\(weekOffset)w ago"
            }
            
            result.append(WeeklyLoad(
                weekStartDate: weekStart,
                totalTrimp: totalTrimp,
                sessionCount: weekSessions.count,
                label: label
            ))
        }
        
        return result.reversed()
    }
    
    // MARK: - Felt vs Measured
    
    struct FeltVsMeasured {
        let sessionCount: Int
        let avgSubjectiveRPE: Double?
        let avgObjectiveIntensity: Double?
        let calibrationHint: CalibrationHint
    }
    
    enum CalibrationHint {
        case notEnoughData
        case aligned
        case underratingEffort
        case overratingEffort
        
        var message: String {
            switch self {
            case .notEnoughData:
                return "Reflect after more sessions to see how your effort aligns with your HR data."
            case .aligned:
                return "Your subjective effort tracks your HR data. Good calibration."
            case .underratingEffort:
                return "You rate sessions easier than your HR suggests. Your cardio fitness may be improving faster than it feels."
            case .overratingEffort:
                return "You rate sessions harder than your HR suggests. Could be strength-heavy work where HR under-reports effort — normal for compound lifts."
            }
        }
        
        var color: String {
            switch self {
            case .notEnoughData:     return "6B7280"
            case .aligned:           return "059669"
            case .underratingEffort: return "2563EB"
            case .overratingEffort:  return "D97706"
            }
        }
        
        var icon: String {
            switch self {
            case .notEnoughData:     return "hourglass"
            case .aligned:           return "checkmark.seal.fill"
            case .underratingEffort: return "arrow.up.right"
            case .overratingEffort:  return "arrow.down.right"
            }
        }
    }
    
    static func feltVsMeasured(sessions: [TrainingSession]) -> FeltVsMeasured {
        let usable = sessions.filter {
            $0.isCompleted
            && $0.subjectiveRPE != nil
            && $0.sessionTrimpScore != nil
            && ($0.sessionTrimpScore ?? 0) > 0
        }
        
        guard usable.count >= 3 else {
            return FeltVsMeasured(
                sessionCount: usable.count,
                avgSubjectiveRPE: nil,
                avgObjectiveIntensity: nil,
                calibrationHint: .notEnoughData
            )
        }
        
        let avgRPE = usable
            .compactMap { $0.subjectiveRPE.map(Double.init) }
            .reduce(0, +) / Double(usable.count)
        
        let intensities = usable.compactMap { session -> Double? in
            guard let trimp = session.sessionTrimpScore else { return nil }
            let scaled = min(10.0, max(1.0, trimp / 15.0))
            return scaled
        }
        let avgObjective = intensities.reduce(0, +) / Double(intensities.count)
        
        let delta = avgRPE - avgObjective
        let hint: CalibrationHint
        if abs(delta) < 1.0 {
            hint = .aligned
        } else if delta > 0 {
            hint = .overratingEffort
        } else {
            hint = .underratingEffort
        }
        
        return FeltVsMeasured(
            sessionCount: usable.count,
            avgSubjectiveRPE: avgRPE,
            avgObjectiveIntensity: avgObjective,
            calibrationHint: hint
        )
    }

    // MARK: - Per-session felt vs measured

    struct PerSessionComparison: Identifiable {
        let id: UUID
        let date: Date
        let sessionType: String
        let subjectiveRPE: Int
        let objectiveIntensity: Double   // scaled 1-10, same basis as feltVsMeasured
    }

    static func perSessionFeltVsMeasured(sessions: [TrainingSession], limit: Int = 5) -> [PerSessionComparison] {
        sessions
            .filter {
                $0.isCompleted
                && $0.subjectiveRPE != nil
                && ($0.sessionTrimpScore ?? 0) > 0
            }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { session in
                PerSessionComparison(
                    id: session.id,
                    date: session.date,
                    sessionType: session.sessionType,
                    subjectiveRPE: session.subjectiveRPE ?? 0,
                    objectiveIntensity: min(10.0, max(1.0, (session.sessionTrimpScore ?? 0) / 15.0))
                )
            }
    }

    // MARK: - Helpers

    private static func totalVolume(for session: TrainingSession) -> Double {
        session.exercises.reduce(0.0) { total, ex in
            total + ex.sets.filter { $0.isCompleted }.reduce(0.0) {
                $0 + ($1.weightKg * Double($1.reps))
            }
        }
    }

    private static func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: date
        )
        return calendar.date(from: components) ?? date
    }
}
