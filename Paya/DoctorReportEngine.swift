import Foundation
import SwiftData

// MARK: - Doctor Report Engine
//
// A different artifact than the raw CSV export already in Settings — this
// aggregates the period into the handful of numbers a rheumatology visit
// actually uses (flare frequency, sleep/HRV trend, training load,
// medication adherence, any strong correlations found), formatted to read
// on paper, not to be re-imported into a spreadsheet.

struct DoctorReport {
    let periodStart: Date
    let periodDays: Int
    let profileName: String

    let flareDayCount: Int
    let flareDates: [Date]

    let avgSleepHours: Double?
    let avgHRV: Double?
    let avgRestingHR: Double?
    let sleepTrend: String   // "improving" / "declining" / "stable" / "not enough data"

    let totalSessions: Int
    let totalVolumeKg: Double
    let avgSessionsPerWeek: Double

    struct MedicationAdherence {
        let name: String
        let dose: String
        let frequency: String
        let dosesExpected: Int
        let dosesTaken: Int
        var adherencePercent: Int {
            guard dosesExpected > 0 else { return 0 }
            return Int((Double(dosesTaken) / Double(dosesExpected) * 100).rounded())
        }
    }
    let medications: [DoctorReportEngine.MedicationAdherence]

    let topCorrelations: [CorrelationEngine.Insight]

    // New: behavior summary
    let topBehaviors: [(tag: String, count: Int)]
    let avgCheckInEnergy: Double?
    let avgCheckInSoreness: Double?
    let checkInCount: Int
}

enum DoctorReportEngine {

    typealias MedicationAdherence = DoctorReport.MedicationAdherence

    @MainActor
    static func generate(daysBack: Int, profileName: String, context: ModelContext, progress: LoadProgress? = nil) async -> DoctorReport {
        progress?.reset(total: 5)
        let calendar = Calendar.current
        let periodStart = calendar.date(byAdding: .day, value: -daysBack, to: .now) ?? .now
        let pid = ActiveProfile.id

        // Flare days
        let healthDescriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.date >= periodStart && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let healthLogs = (try? context.fetch(healthDescriptor)) ?? []
        let flareDates = healthLogs.filter { $0.isFlareDay }.map { $0.date }
        progress?.step("Flare history")

        // Biometrics
        let biometrics = BiometricStore.shared
        if biometrics.history.isEmpty {
            await biometrics.loadHistory(daysBack: daysBack)
        }
        progress?.step("Sleep & recovery")
        let inWindow = biometrics.history.filter { $0.date >= periodStart }
        let sleepValues = inWindow.compactMap(\.sleepHours)
        let hrvValues = inWindow.compactMap(\.hrv)
        let rhrValues = inWindow.compactMap(\.restingHR)
        let avgSleep = sleepValues.isEmpty ? nil : sleepValues.reduce(0, +) / Double(sleepValues.count)
        let avgHRV = hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count)
        let avgRHR = rhrValues.isEmpty ? nil : rhrValues.reduce(0, +) / Double(rhrValues.count)

        let sleepTrend: String = {
            let sorted = inWindow.sorted { $0.date < $1.date }.compactMap { day -> (Date, Double)? in
                guard let s = day.sleepHours else { return nil }
                return (day.date, s)
            }
            guard sorted.count >= 6 else { return "not enough data" }
            let mid = sorted.count / 2
            let firstAvg = sorted[..<mid].map(\.1).reduce(0, +) / Double(mid)
            let secondAvg = sorted[mid...].map(\.1).reduce(0, +) / Double(sorted.count - mid)
            let delta = secondAvg - firstAvg
            if delta > 0.3 { return "improving" }
            if delta < -0.3 { return "declining" }
            return "stable"
        }()

        // Training load
        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.date >= periodStart && $0.profileId == pid && $0.isCompleted == true }
        )
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []
        let totalVolume = sessions.reduce(0.0) { total, session in
            total + session.exercises.reduce(0.0) { t, ex in
                t + ex.sets.filter { $0.isCompleted }.reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
            }
        }
        let weeks = max(1.0, Double(daysBack) / 7.0)
        let avgSessionsPerWeek = Double(sessions.count) / weeks
        progress?.step("Training load")

        // Medication adherence
        let medications = MedicationStore.active(context: context).map { medication -> MedicationAdherence in
            let id = medication.id
            let logDescriptor = FetchDescriptor<MedicationDoseLog>(
                predicate: #Predicate<MedicationDoseLog> { $0.medicationId == id && $0.takenAt >= periodStart }
            )
            let dosesTaken = (try? context.fetch(logDescriptor))?.count ?? 0
            let dosesExpected: Int
            if let interval = medication.frequency.intervalDays {
                dosesExpected = max(1, daysBack / interval)
            } else {
                dosesExpected = 0 // as-needed — no expected cadence to measure against
            }
            return MedicationAdherence(
                name: medication.name,
                dose: medication.dose,
                frequency: medication.frequency.displayName,
                dosesExpected: dosesExpected,
                dosesTaken: dosesTaken
            )
        }

        progress?.step("Medication adherence")

        // Check-in & behavior data
        let checkInDescriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate<DailyCheckIn> { $0.date >= periodStart && $0.profileId == pid }
        )
        let checkIns = (try? context.fetch(checkInDescriptor)) ?? []
        let avgEnergy = checkIns.isEmpty ? nil : Double(checkIns.map(\.energy).reduce(0, +)) / Double(checkIns.count)
        let avgSoreness = checkIns.isEmpty ? nil : Double(checkIns.map(\.soreness).reduce(0, +)) / Double(checkIns.count)

        let behaviorDescriptor = FetchDescriptor<BehaviorLog>(
            predicate: #Predicate<BehaviorLog> { $0.date >= periodStart && $0.profileId == pid }
        )
        let behaviorLogs = (try? context.fetch(behaviorDescriptor)) ?? []
        let allTags = behaviorLogs.flatMap(\.tagIds)
        let tagCounts = Dictionary(allTags.map { ($0, 1) }, uniquingKeysWith: +)
        let topBehaviors = tagCounts.sorted { $0.value > $1.value }.prefix(5).map { (tag: $0.key, count: $0.value) }

        // Correlations worth mentioning
        let dailyMetrics = await CorrelationEngine.gatherDailyMetrics(daysBack: daysBack, context: context)
        let insights = Array(CorrelationEngine.discoverInsights(from: dailyMetrics).prefix(3))
        progress?.step("Patterns")

        return DoctorReport(
            periodStart: periodStart,
            periodDays: daysBack,
            profileName: profileName,
            flareDayCount: flareDates.count,
            flareDates: flareDates,
            avgSleepHours: avgSleep,
            avgHRV: avgHRV,
            avgRestingHR: avgRHR,
            sleepTrend: sleepTrend,
            totalSessions: sessions.count,
            totalVolumeKg: totalVolume,
            avgSessionsPerWeek: avgSessionsPerWeek,
            medications: medications,
            topCorrelations: insights,
            topBehaviors: topBehaviors,
            avgCheckInEnergy: avgEnergy,
            avgCheckInSoreness: avgSoreness,
            checkInCount: checkIns.count
        )
    }
}
