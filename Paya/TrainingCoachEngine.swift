import Foundation
import SwiftData

// MARK: - Training Coach Engine
//
// AI's job here is narration, not mechanics: it reads the same computed
// signals a human coach would (plateau flags, volume-landmark zones, deload
// status, recent PR trend) and writes a short, specific recommendation. The
// actual program change — if the user acts on it — runs back through
// TrainingScienceEngine/ProgramAssembler, the same deterministic,
// science-grounded pipeline onboarding uses. The AI never invents exercises
// or prescriptions directly; it explains what the data already shows and,
// at most, points at which muscle priority to rebuild toward. This mirrors
// LifestylePlanEngine's split (AI narrates, rule engines compute).

enum TrainingCoachEngine {

    @MainActor
    static func generateRecommendation(profile: PersonProfile, context: ModelContext, apiKey: String) async -> String? {
        let system = """
        You are an evidence-based strength coach reviewing one lifter's actual \
        logged data. Rules: \
        1) Reference the SPECIFIC exercises and numbers provided — never \
        invent exercises the lifter doesn't do. \
        2) Ground every suggestion in one named principle (e.g. "progressive \
        overload", "Israetel's MRV", "Schoenfeld 2017 volume dose-response", \
        "ACSM rep-range continuum"). \
        3) Give ONE concrete next action with an exact number (e.g. "add 2.5 kg \
        to your bench press next session" or "add 2 weekly sets of rows"). \
        4) Do NOT reorder exercises, rename them, or suggest swapping unless \
        the data shows a clear reason (plateau on that lift, volume imbalance \
        for that muscle). \
        5) Keep it to 3-5 short sentences, plain and direct. This appears in \
        a fitness app, not a report.
        """

        let userMessage = buildUserMessage(profile: profile, context: context)
        let result = await AIService.shared.generate(system: system, userMessage: userMessage, apiKey: apiKey, requiresReasoning: true)
        if let result {
            profile.cachedCoachRecommendation = result
            profile.coachRecommendationGeneratedAt = .now
        }
        return result
    }

    @MainActor
    private static func buildUserMessage(profile: PersonProfile, context: ModelContext) -> String {
        var lines: [String] = []
        lines.append("Goal: \(profile.goal.displayName). Experience: \(profile.experienceLevel.displayName). Trains \(profile.preferredTrainingDaysPerWeek)x/week.")

        let pid = ActiveProfile.id
        let weekAgo = Calendar.current.date(byAdding: .day, value: -35, to: .now) ?? .now
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.isCompleted == true && $0.date >= weekAgo && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let sessions = (try? context.fetch(descriptor)) ?? []

        if sessions.isEmpty {
            lines.append("No completed sessions logged in the last 5 weeks — this person is either brand new or has been away from training.")
            return lines.joined(separator: "\n")
        }
        lines.append("\(sessions.count) sessions completed in the last 5 weeks.")

        // Concrete exercise data: best set per exercise across recent sessions
        var exerciseBests: [String: (name: String, weight: Double, reps: Int, muscle: String, sessionCount: Int)] = [:]
        for session in sessions {
            for exercise in session.exercises {
                let completedSets = exercise.sets.filter { $0.isCompleted && $0.weightKg > 0 }
                guard let best = completedSets.max(by: { ($0.weightKg * (1 + Double($0.reps) / 30.0)) < ($1.weightKg * (1 + Double($1.reps) / 30.0)) }) else { continue }
                let existing = exerciseBests[exercise.exerciseId]
                let e1rm = best.weightKg * (1 + Double(best.reps) / 30.0)
                let prevE1rm = existing.map { $0.weight * (1 + Double($0.reps) / 30.0) } ?? 0
                let count = (existing?.sessionCount ?? 0) + 1
                if e1rm >= prevE1rm {
                    exerciseBests[exercise.exerciseId] = (exercise.exerciseName, best.weightKg, best.reps, exercise.muscleGroup, count)
                } else if var e = existing {
                    e.sessionCount = count
                    exerciseBests[exercise.exerciseId] = e
                }
            }
        }
        if !exerciseBests.isEmpty {
            lines.append("\nRecent best sets:")
            for (_, data) in exerciseBests.sorted(by: { $0.value.sessionCount > $1.value.sessionCount }).prefix(8) {
                let e1rm = data.weight * (1 + Double(data.reps) / 30.0)
                lines.append("  \(data.name) (\(data.muscle)): \(String(format: "%.1f", data.weight)) kg × \(data.reps) reps (e1RM \(String(format: "%.0f", e1rm)) kg), done \(data.sessionCount)× in 5 weeks")
            }
        }

        let plateaus = PlateauEngine.detect(sessions: sessions)
        if !plateaus.isEmpty {
            lines.append("\nStalled lifts (no e1RM progress in 3+ sessions):")
            for p in plateaus.prefix(4) {
                lines.append("  \(p.exerciseName): e1RM stuck at \(String(format: "%.0f", p.currentE1RM)) kg for \(p.sessionsStalled) sessions (peak was \(String(format: "%.0f", p.peakE1RM)) kg)")
            }
        }

        let volumes = VolumeLandmarkEngine.weeklyVolume(sessions: sessions)
        let volumeDetails = volumes.sorted { $0.muscleGroup < $1.muscleGroup }
        if !volumeDetails.isEmpty {
            lines.append("\nWeekly volume per muscle (sets/week):")
            for v in volumeDetails {
                let zone = v.zone == .under ? "UNDER MEV" : v.zone == .excessive ? "OVER MRV" : "OK"
                lines.append("  \(v.muscleGroup): \(v.sets) sets [\(zone)] (MEV: \(v.landmark.mev), MRV: \(v.landmark.mrv))")
            }
        }

        if DeloadEngine.isDeloadActive {
            lines.append("\nCurrently in an active deload week.")
        } else {
            let suggestion = DeloadEngine.evaluate(context: context)
            if suggestion.isDue {
                lines.append("\nDeload is due: \(suggestion.reason)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Deterministic rebuild target (no AI involved)

    /// The most under-trained muscle mappable to a MusclePriority, purely
    /// from logged volume data — this is what "rebuild my program" actually
    /// acts on, kept separate from anything the AI writes so a program
    /// change is never driven by a hallucinated suggestion.
    static func suggestedPriorityMuscle(sessions: [TrainingSession]) -> MusclePriority? {
        let volumes = VolumeLandmarkEngine.weeklyVolume(sessions: sessions)
        let underTrained = volumes
            .filter { $0.zone == .under }
            .sorted { ($0.landmark.mev - $0.sets) > ($1.landmark.mev - $1.sets) }

        let mapping: [String: MusclePriority] = [
            "Chest": .chest, "Back": .back, "Shoulders": .shoulders,
            "Quads": .legs, "Hamstrings": .legs, "Glutes": .legs,
            "Biceps": .arms, "Triceps": .arms
        ]
        for mv in underTrained {
            if let priority = mapping[mv.muscleGroup] { return priority }
        }
        return nil
    }

    @MainActor
    static func rebuildProgram(profile: PersonProfile, context: ModelContext, priorityMuscle: MusclePriority) {
        guard let recommendation = TrainingScienceEngine.recommend(
            goal: profile.goal,
            experience: profile.experienceLevel,
            equipment: profile.equipmentAccess,
            injuries: profile.injuryFlags,
            daysPerWeek: profile.preferredTrainingDaysPerWeek,
            priorityMuscle: priorityMuscle,
            sexRaw: profile.sexRaw
        ) else { return }

        profile.priorityMuscleRaw = priorityMuscle.rawValue
        ProgramInstaller.install(recommendation.template, context: context, volumeAdjustment: recommendation.volumeAdjustment)
    }
}
