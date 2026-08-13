import Foundation
import SwiftData

// MARK: - Soreness Correlation Engine
//
// Answers the actual question a user has the morning after training: "is
// today's soreness where I trained hard yesterday, or somewhere else?"
// DailyCheckIn.soreness is one overall 1-5 number — it can't answer that.
// This cross-references MuscleActivationEngine's per-region effort from the
// most recent session against SorenessRegionLog's tapped sore regions for
// today, region by region, instead of guessing at a whole-body correlation
// coefficient off far too little data to compute one honestly.

enum SorenessCorrelationEngine {

    struct RegionVerdict: Identifiable {
        var id: BodyRegion { region }
        let region: BodyRegion
        let trainedHard: Bool       // moderate zone or higher yesterday
        let isSoreToday: Bool
        let sorenessKind: SorenessKind?
        let isVolumeBased: Bool
    }

    struct Result {
        let referenceSession: TrainingSession?
        let referenceIsYesterday: Bool
        let regionColors: [BodyRegion: (colorHex: String, isVolumeBased: Bool)]
        let verdicts: [RegionVerdict]

        var matchedCount: Int { verdicts.filter { $0.isSoreToday && $0.trainedHard }.count }
        var soreCount: Int { verdicts.filter { $0.isSoreToday }.count }
        var unexplainedCount: Int { verdicts.filter { $0.isSoreToday && !$0.trainedHard }.count }
        var flareTaggedUnexplainedCount: Int {
            verdicts.filter { $0.isSoreToday && !$0.trainedHard && $0.sorenessKind == .flare }.count
        }

        var summary: String? {
            guard referenceSession != nil, soreCount > 0 else { return nil }
            if flareTaggedUnexplainedCount > 0 {
                return "\(flareTaggedUnexplainedCount) spot\(flareTaggedUnexplainedCount == 1 ? "" : "s") tagged as flare/joint pain don't match anything trained in the last 3 days — worth tracking if this is part of a pattern."
            } else if unexplainedCount == 0 {
                return "All \(soreCount) sore spot\(soreCount == 1 ? "" : "s") today line up with your last 3 days of training."
            } else if matchedCount == 0 {
                return "None of today's \(soreCount) sore spot\(soreCount == 1 ? "" : "s") match your last 3 days of training — could be from further back or daily life."
            } else {
                return "\(matchedCount) of \(soreCount) sore spots match your recent training; \(unexplainedCount) don't line up with anything trained in the last 3 days."
            }
        }
    }

    @MainActor
    static func analyze(context: ModelContext, maxHR: Int) -> Result {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now)) ?? .now
        let todayStart = calendar.startOfDay(for: .now)

        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.isCompleted == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []
        let yesterdaySession = sessions.first { calendar.isDate($0.date, inSameDayAs: yesterdayStart) }
        let referenceSession = yesterdaySession ?? sessions.first
        let isYesterday = yesterdaySession != nil

        var regionColors: [BodyRegion: (String, Bool)] = [:]
        var trainedRegions: Set<BodyRegion> = []
        var volumeBasedRegions: Set<BodyRegion> = []

        if let session = referenceSession {
            let activation = MuscleActivationEngine.analyze(session: session, maxHR: maxHR)
            for (muscle, act) in activation {
                for region in MuscleActivationEngine.regions(for: muscle) {
                    regionColors[region] = (act.zone.colorHex, act.isVolumeBased)
                    if act.isVolumeBased { volumeBasedRegions.insert(region) }
                    switch act.zone {
                    case .moderate, .vigorous, .nearMax: trainedRegions.insert(region)
                    case .light, .noData: break
                    }
                }
            }
        }

        // DOMS (delayed-onset muscle soreness) commonly peaks 24-72h after
        // training, not just the next morning (Cheung K, et al. "Delayed
        // Onset Muscle Soreness." Sports Med, 2003) — so "does today's
        // soreness match training" should look back further than the single
        // most recent session, even though the body map above only ever
        // pictures that one session for visual clarity.
        let lookbackStart = calendar.date(byAdding: .day, value: -3, to: todayStart) ?? todayStart
        for session in sessions where session.date >= lookbackStart && session !== referenceSession {
            let activation = MuscleActivationEngine.analyze(session: session, maxHR: maxHR)
            for (muscle, act) in activation {
                switch act.zone {
                case .moderate, .vigorous, .nearMax:
                    for region in MuscleActivationEngine.regions(for: muscle) { trainedRegions.insert(region) }
                case .light, .noData:
                    break
                }
            }
        }

        let soreDescriptor = FetchDescriptor<SorenessRegionLog>(
            predicate: #Predicate<SorenessRegionLog> { $0.profileId == pid && $0.date >= todayStart }
        )
        let soreEntries = ((try? context.fetch(soreDescriptor)) ?? []).last?.entries ?? []
        let soreKindByRegion = Dictionary(uniqueKeysWithValues: soreEntries.map { ($0.region, $0.kind) })

        let verdicts = BodyRegion.allCases.map { region in
            RegionVerdict(
                region: region,
                trainedHard: trainedRegions.contains(region),
                isSoreToday: soreKindByRegion[region] != nil,
                sorenessKind: soreKindByRegion[region],
                isVolumeBased: volumeBasedRegions.contains(region)
            )
        }

        return Result(
            referenceSession: referenceSession,
            referenceIsYesterday: isYesterday,
            regionColors: regionColors,
            verdicts: verdicts
        )
    }

    @MainActor
    static func todaysSoreEntries(context: ModelContext) -> [(region: BodyRegion, kind: SorenessKind)] {
        let pid = ActiveProfile.id
        let todayStart = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<SorenessRegionLog>(
            predicate: #Predicate<SorenessRegionLog> { $0.profileId == pid && $0.date >= todayStart }
        )
        return ((try? context.fetch(descriptor)) ?? []).last?.entries ?? []
    }

    /// Cycles a region through off → sore (DOMS) → flare/joint pain → off,
    /// one tap at a time — a plain soreness number can't distinguish
    /// expected post-training soreness from chronic-condition pain, and
    /// that distinction is exactly what someone managing a flare needs.
    @MainActor
    static func cycle(_ region: BodyRegion, context: ModelContext) {
        let pid = ActiveProfile.id
        let todayStart = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<SorenessRegionLog>(
            predicate: #Predicate<SorenessRegionLog> { $0.profileId == pid && $0.date >= todayStart }
        )
        let existing = ((try? context.fetch(descriptor)) ?? []).last
        var entries = existing?.entries ?? []

        if let idx = entries.firstIndex(where: { $0.region == region }) {
            switch entries[idx].kind {
            case .doms: entries[idx].kind = .flare
            case .flare: entries.remove(at: idx)
            }
        } else {
            entries.append((region, .doms))
        }

        if let existing {
            existing.entries = entries
        } else {
            let log = SorenessRegionLog(entries: entries)
            log.profileId = pid
            context.insert(log)
        }
        try? context.save()
    }
}
