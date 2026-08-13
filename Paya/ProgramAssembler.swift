import Foundation

// MARK: - Program Assembler
//
// Generates a ProgramTemplate from scratch per user instead of matching one
// of ~20 pre-authored plans. Exercise count and rest/rep/set volume scale to
// the goal, but scale sanely — a real full-body hypertrophy session runs
// 5-7 lifts, not every pattern plus every accessory crammed into one
// sitting. Full-body days also no longer stack both major lower-body
// compounds (squat AND a heavy hinge) into the same session — each day has
// ONE primary lower-body pattern, alternating squat/hinge/unilateral
// emphasis across the week, the way real full-body A/B/C templates are
// built. Equipment fit is a hard filter (see `pick`) with a quality
// preference on top: a full-gym user should land on gym-caliber lifts, not
// the bodyweight fallback that exists for people who lack any equipment.
//
// Sex-based adjustments (deliberately narrow, evidence-grounded, not a
// blanket "different program for women"): ACSM/NSCA position stands are
// explicit that resistance-training principles — progressive overload,
// volume landmarks, rep ranges per goal — are the same regardless of sex;
// there's no legitimate basis for a fundamentally different hypertrophy or
// strength program by sex, and building one would be exactly the kind of
// unscientific "toning" myth this app should avoid. Two things ARE
// well-supported in the literature and are applied here:
//   1. Fatigue resistance: women show greater resistance to fatigue in
//      sustained/repeated submaximal contractions (Hunter, 2014 sex-
//      differences-in-fatigability review) — reflected as a modest (10%)
//      rest-period reduction, not a volume or exercise change.
//   2. ACL injury risk: female athletes have a well-documented 2-8x higher
//      ACL injury rate in comparable sports, substantially attributable to
//      neuromuscular/biomechanical factors (dynamic knee valgus, quad-
//      dominant landing patterns) rather than anatomy alone (Hewett/Myer
//      neuromuscular training research). Structured hip/glute activation
//      work measurably reduces this risk — a 2025 meta-analysis of 11 RCTs
//      across 12,675 female team-sport athletes found neuromuscular
//      training programs cut overall knee injury risk 22% and ACL injury
//      risk specifically 50%. That's reflected as one hip-stability
//      exercise added on days with a knee-dominant pattern — genuine
//      injury-prevention science, available to anyone, applied by default
//      for female profiles since that's the population the research is
//      about.

enum DayArchetype: String {
    case fullBody = "Full body"
    case upper = "Upper"
    case lower = "Lower"
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"

    /// Priority-ordered pattern slots — highest-priority (most essential)
    /// first, so lower-volume goals can trim from the end without losing
    /// the movements that matter most for that day's job. Full-body uses
    /// `fullBodyVariant` instead (see below) since it varies per day index.
    var basePatterns: [MovementPattern] {
        switch self {
        case .fullBody: return []   // handled by fullBodyVariant(dayIndex:)
        case .upper:    return [.horizontalPush, .horizontalPull, .verticalPush, .verticalPull, .sideDelt, .rearDelt, .biceps, .triceps]
        case .lower:    return [.squat, .hinge, .lunge, .hipThrust, .core, .calves]
        case .push:     return [.horizontalPush, .horizontalPush, .verticalPush, .core, .sideDelt, .triceps]
        case .pull:     return [.verticalPull, .horizontalPull, .horizontalPull, .core, .rearDelt, .biceps]
        case .legs:     return [.squat, .hinge, .lunge, .hipThrust, .core, .calves]
        }
    }

    /// Shown under the day name in the UI — deliberately NOT the archetype
    /// name itself (e.g. "Push"), since the day name already says "Push A"
    /// and a subtitle that just repeats part of the title is dead visual
    /// weight, not information.
    var focusLabel: String {
        switch self {
        case .fullBody: return ""   // set per-variant, see fullBodyVariantFocusLabels
        case .upper:    return "Push, pull & delts"
        case .lower:    return "Squat, hinge & unilateral"
        case .push:     return "Chest, shoulders & triceps"
        case .pull:     return "Back, rear delts & biceps"
        case .legs:     return "Squat, hinge & unilateral"
        }
    }

    /// Extra slots appended (not trimmed from) for goals whose volume
    /// landmarks call for more total work per session than the base list.
    var hypertrophyBonusPatterns: [MovementPattern] {
        switch self {
        case .fullBody: return []   // handled by fullBodyBonusVariant(dayIndex:)
        case .upper:    return []   // base list already has all 8 upper-body patterns
        case .lower:    return [.squat]   // second knee-dominant slot (isolation variant)
        case .push:     return [.triceps]
        case .pull:     return [.biceps]
        case .legs:     return [.squat]
        }
    }

    /// Full-body day variants: each day trains ONE primary lower-body
    /// pattern (never squat AND a heavy hinge in the same session — that's
    /// two demanding compound patterns stacked on the same lower back/CNS
    /// for no frequency benefit at 2-3x/week), rotating squat/hinge/
    /// unilateral emphasis so every pattern still gets covered across the
    /// week.
    /// Each day covers a full push/pull/lower/core slate PLUS one direct-arm
    /// and one calf slot, rotated so every pattern — including biceps and
    /// calves, previously absent from every generated full-body day — gets
    /// hit at least once across the week. This mirrors how the hand-authored
    /// full-body templates are actually built (they never skip arms or
    /// calves) instead of treating them as hypertrophy-only bonus content.
    static let fullBodyVariants: [[MovementPattern]] = [
        [.squat, .horizontalPush, .horizontalPull, .core, .sideDelt, .calves],    // Day A — squat-dominant
        [.hinge, .verticalPush, .verticalPull, .core, .rearDelt, .biceps],        // Day B — hinge-dominant
        [.lunge, .horizontalPush, .horizontalPull, .core, .hipThrust, .triceps]   // Day C — unilateral + posterior
    ]

    /// Per-variant focus label shown under the day name — describes the
    /// actual pattern emphasis (matching the comments above) instead of
    /// just restating "Full body", which the day name already says.
    static let fullBodyVariantFocusLabels: [String] = [
        "Squat-dominant", "Hinge-dominant", "Unilateral + posterior"
    ]

    /// One extra slot per full-body variant for goals with the volume
    /// headroom for it — chosen to add a second push/pull variant rather
    /// than a second lower-body compound (stacking two heavy lower-body
    /// patterns in one full-body session is exactly what the day-variant
    /// rotation above exists to avoid).
    static let fullBodyHypertrophyBonus: [MovementPattern] = [.verticalPush, .horizontalPush, .verticalPull]
}

/// Short, pattern-level "why this is here" — appended to each exercise's
/// coaching note, which the workout UI already surfaces (ExerciseCardView's
/// "Coaching Note" section). This is what makes the science behind exercise
/// selection visible to the user instead of only existing in generator code
/// they never see.
private func patternRationale(_ pattern: MovementPattern) -> String {
    switch pattern {
    case .squat: return "Knee-dominant compound — the highest-transfer quad/glute builder in the pattern."
    case .lunge: return "Unilateral knee-dominant work — trains each leg independently, exposing and correcting side-to-side imbalances a bilateral squat can hide."
    case .hinge: return "Hip-dominant compound — the primary hamstring/glute pattern, and the main counterbalance to squat-only leg training."
    case .hipThrust: return "Highest acute glute EMG of any common exercise — but a controlled trial found squat and hip thrust build the glutes equally over time, while squat alone drives superior quad/adductor growth, so this complements squat rather than replacing it."
    case .horizontalPush: return "Horizontal push — foundational chest/front-delt/tricep compound."
    case .verticalPush: return "Vertical push — shoulder-dominant pressing most horizontal-push work under-trains."
    case .horizontalPull: return "Horizontal pull — balances horizontal push volume; under-training this relative to pushing is a common cause of rounded-shoulder posture."
    case .verticalPull: return "Vertical pull — lat-dominant, the main back-width driver. Grip/width doesn't reliably change lat activation across variants, so pick whichever grip is comfortable on your shoulders."
    case .sideDelt: return "Side-delt isolation — presses alone under-train this head; direct work is what actually grows shoulder width."
    case .rearDelt: return "Rear-delt/scapular work — the most commonly neglected upper-body muscle, and important for shoulder-joint health under heavy pressing."
    case .biceps: return "Direct arm isolation — pulling compounds hit biceps synergistically, but direct work adds targeted volume for growth."
    case .triceps: return "Direct arm isolation — pressing compounds hit triceps synergistically, but direct work adds targeted volume for growth."
    case .calves: return "Calves respond to direct, high-frequency volume more than compounds provide on their own."
    case .core: return "Anti-extension/flexion core work — supports spinal stability under the day's heavier compounds."
    case .cardioFinisher: return "Metabolic finisher — adds energy-expenditure density without competing with the main lifts' recovery demands."
    case .hipStability: return "Hip/glute activation — neuromuscular injury-prevention work (Hewett/Myer ACL-injury-prevention research), done before loaded knee-dominant work."
    }
}

private func isCompound(_ pattern: MovementPattern) -> Bool {
    switch pattern {
    case .squat, .lunge, .hinge, .hipThrust, .horizontalPush, .verticalPush, .horizontalPull, .verticalPull:
        return true
    case .sideDelt, .rearDelt, .biceps, .triceps, .calves, .core, .cardioFinisher, .hipStability:
        return false
    }
}

/// Lower-body patterns where dynamic knee valgus during loaded/plyometric
/// movement is the mechanism of concern for the hip-stability addition below.
private let kneeDominantPatterns: Set<MovementPattern> = [.squat, .lunge, .hinge, .hipThrust]

private struct GoalVolumeProfile {
    let slotTrim: Int              // low-priority slots dropped from the end of basePatterns
    let compoundSets: Int
    let isolationSets: Int
    let compoundReps: ClosedRange<Int>
    let isolationReps: ClosedRange<Int>
    let compoundRest: Int
    let isolationRest: Int
    let appendCardioFinisher: Bool
    let addHypertrophyBonusSlots: Bool
    let intensityNote: String

    /// Rep ranges and set counts follow the volume-landmark literature
    /// (Schoenfeld et al. frequency/volume meta-analyses; NSCA position
    /// stand on program design): hypertrophy sits at 8-12/10-15 reps with
    /// the highest total set volume of any goal here; strength drops reps
    /// to 3-6 on compounds with longer rest for full ATP-CP recovery between
    /// max-effort sets; fat loss and endurance trade load for density
    /// (shorter rest, higher reps) since the metabolic/muscular-endurance
    /// stimulus — not absolute load — is the target adaptation.
    static func forGoal(_ goal: TrainingGoal) -> GoalVolumeProfile {
        switch goal {
        case .hypertrophy:
            return GoalVolumeProfile(slotTrim: 0, compoundSets: 4, isolationSets: 3, compoundReps: 8...12, isolationReps: 10...15, compoundRest: 110, isolationRest: 70, appendCardioFinisher: false, addHypertrophyBonusSlots: true, intensityNote: "RPE 8-9 on the last set of every exercise")
        case .strength:
            return GoalVolumeProfile(slotTrim: 2, compoundSets: 5, isolationSets: 2, compoundReps: 3...6, isolationReps: 8...10, compoundRest: 165, isolationRest: 90, appendCardioFinisher: false, addHypertrophyBonusSlots: false, intensityNote: "RPE 8-9 on compounds, leave the last rep in the tank on accessories")
        case .fatLoss:
            return GoalVolumeProfile(slotTrim: 1, compoundSets: 3, isolationSets: 2, compoundReps: 10...12, isolationReps: 12...15, compoundRest: 70, isolationRest: 50, appendCardioFinisher: true, addHypertrophyBonusSlots: false, intensityNote: "Keep rests honest — the density is part of the deficit")
        case .endurance:
            return GoalVolumeProfile(slotTrim: 1, compoundSets: 3, isolationSets: 3, compoundReps: 15...18, isolationReps: 15...20, compoundRest: 55, isolationRest: 45, appendCardioFinisher: false, addHypertrophyBonusSlots: false, intensityNote: "Higher rep, shorter rest — muscular endurance, not max strength")
        case .stayFit:
            return GoalVolumeProfile(slotTrim: 1, compoundSets: 3, isolationSets: 2, compoundReps: 10...12, isolationReps: 12...15, compoundRest: 90, isolationRest: 60, appendCardioFinisher: false, addHypertrophyBonusSlots: false, intensityNote: "RPE 6-8 — consistency beats grinding")
        }
    }
}

enum ProgramAssembler {

    private static func archetypes(for daysPerWeek: Int) -> [DayArchetype] {
        switch daysPerWeek {
        case ..<3: return Array(repeating: .fullBody, count: 2)
        case 3:    return Array(repeating: .fullBody, count: 3)
        case 4:    return [.upper, .lower, .upper, .lower]
        default:   return [.push, .pull, .legs, .upper, .lower]
        }
    }

    private static let weekdaysBySlotCount: [Int: [Int]] = [
        2: [2, 5],
        3: [2, 4, 6],
        4: [2, 3, 5, 6],
        5: [2, 3, 4, 5, 6]
    ]

    private static let dayColors = ["2563EB", "059669", "D97706", "8B5CF6", "DC2626"]

    static func assemble(
        goal: TrainingGoal,
        experience: ExperienceLevel,
        equipment: EquipmentAccess,
        injuries: Set<InjuryArea>,
        daysPerWeek: Int,
        priorityMuscle: MusclePriority = .none,
        sexRaw: String = "male"
    ) -> ProgramTemplate {
        let isFemale = sexRaw.lowercased() == "female"
        let clamped = min(max(daysPerWeek, TrainingScienceEngine.allowedDaysRange.lowerBound), TrainingScienceEngine.allowedDaysRange.upperBound)
        let archetypes = archetypes(for: clamped)
        let profile = GoalVolumeProfile.forGoal(goal)
        let weekdays = weekdaysBySlotCount[archetypes.count] ?? Array(2...(1 + archetypes.count))

        var usedThisWeek = Set<String>()
        var days: [TemplateDay] = []
        var fullBodyDayCount = 0

        for (index, archetype) in archetypes.enumerated() {
            var patterns: [MovementPattern]
            var bonus: [MovementPattern]
            var dayFocusLabel = archetype.focusLabel

            if archetype == .fullBody {
                let variantIndex = fullBodyDayCount % DayArchetype.fullBodyVariants.count
                patterns = DayArchetype.fullBodyVariants[variantIndex]
                bonus = [DayArchetype.fullBodyHypertrophyBonus[variantIndex]]
                dayFocusLabel = DayArchetype.fullBodyVariantFocusLabels[variantIndex]
                fullBodyDayCount += 1
            } else {
                patterns = archetype.basePatterns
                bonus = archetype.hypertrophyBonusPatterns
            }

            if profile.slotTrim > 0 {
                patterns.removeLast(min(profile.slotTrim, max(0, patterns.count - 3)))
            }
            if profile.addHypertrophyBonusSlots {
                patterns.append(contentsOf: bonus)
            }
            // One extra slot for a chosen focus muscle — capped so "focus"
            // means a bigger share of an already-sane session, not another
            // exercise piled on top of a day that's already full.
            if goal == .hypertrophy, let focusPattern = priorityMuscle.bonusPattern, patterns.count < 7 {
                patterns.append(focusPattern)
            }
            // Hip/glute activation before knee-dominant work — see the
            // ACL-injury-prevention note above (Hewett/Myer). One exercise,
            // not a program overhaul.
            if isFemale, patterns.contains(where: { kneeDominantPatterns.contains($0) }) {
                patterns.append(.hipStability)
            }

            var exercises: [TemplateExercise] = []
            var usedToday = Set<String>()
            var isFirstCompound = true

            for pattern in patterns {
                guard let picked = pick(pattern: pattern, level: experience, equipment: equipment, injuries: injuries, usedToday: usedToday, usedThisWeek: usedThisWeek) else { continue }
                usedToday.insert(picked.name)
                usedThisWeek.insert(picked.name)

                let compound = isCompound(pattern)
                let sets = compound ? profile.compoundSets : profile.isolationSets
                let reps = compound ? profile.compoundReps : profile.isolationReps
                // Women show greater resistance to fatigue in sustained
                // submaximal contractions (Hunter, 2014) — a modest rest
                // reduction, not a volume or exercise change.
                let baseRest = compound ? profile.compoundRest : profile.isolationRest
                let rest = isFemale ? Int((Double(baseRest) * 0.9).rounded()) : baseRest

                var note = picked.note.isEmpty ? patternRationale(pattern) : "\(picked.note) · \(patternRationale(pattern))"
                if compound && isFirstCompound {
                    let warmupCue = "Warm up with 2 lighter ramp-up sets before your first work set"
                    note = "\(warmupCue) · \(note)"
                    isFirstCompound = false
                }

                exercises.append(TemplateExercise(
                    name: picked.name,
                    sets: sets,
                    repMin: reps.lowerBound,
                    repMax: reps.upperBound,
                    startWeightKg: picked.startWeightKg,
                    restSeconds: rest,
                    jointSensitive: picked.jointSensitive,
                    note: note,
                    muscleGroup: picked.muscleGroup,
                    alternatives: picked.alternatives
                ))
            }

            if profile.appendCardioFinisher {
                let finishers = ExercisePool.candidates(for: .cardioFinisher, level: experience)
                if let finisher = finishers.first(where: { !usedThisWeek.contains($0.name) }) ?? finishers.first {
                    usedThisWeek.insert(finisher.name)
                    exercises.append(TemplateExercise(
                        name: finisher.name, sets: 3, repMin: 20, repMax: 30,
                        startWeightKg: finisher.startWeightKg, restSeconds: 45,
                        note: finisher.note, muscleGroup: finisher.muscleGroup, alternatives: finisher.alternatives
                    ))
                }
            }

            let letter = String(UnicodeScalar(65 + index)!)
            days.append(TemplateDay(
                code: letter,
                name: "\(archetype.rawValue) \(letter)",
                focus: dayFocusLabel,
                colorHex: dayColors[index % dayColors.count],
                weekday: weekdays[index % weekdays.count],
                exercises: exercises
            ))
        }

        return ProgramTemplate(
            id: "gen_\(goal.rawValue)_\(clamped)d_\(experience.rawValue)",
            name: "Personalized \(goal.displayName) \(clamped)×",
            goal: goal,
            tier: experience.tier,
            daysPerWeek: clamped,
            summary: "Generated for you: \(profile.intensityNote.lowercased()). Every day is built from real movement-pattern coverage for this split, not a fixed catalogue entry. Progression: double progression per exercise (add a rep each session until you hit the top of the range, then add weight and drop back to the bottom) — with an automatic deload (~35% lighter) after 5 consecutive training weeks to dissipate fatigue before the next block.",
            days: days
        )
    }

    /// Picks the best-fit exercise for a pattern slot: equipment fit is a
    /// hard filter (never surfaces something the user can't actually do),
    /// then prefers gym-caliber loading for full-gym users over the
    /// bodyweight fallback that exists for people without equipment, then
    /// prefers whatever hasn't appeared yet this week for variety, then
    /// whatever avoids a flagged injury area.
    private static func pick(
        pattern: MovementPattern,
        level: ExperienceLevel,
        equipment: EquipmentAccess,
        injuries: Set<InjuryArea>,
        usedToday: Set<String>,
        usedThisWeek: Set<String>
    ) -> PoolExercise? {
        let candidates = ExercisePool.candidates(for: pattern, level: level)
        guard !candidates.isEmpty else { return nil }

        func fitsEquipment(_ ex: PoolExercise) -> Bool {
            switch equipment {
            case .fullGym: return true
            case .homeDumbbells: return ex.equipmentTag.worksWithDumbbellsAtHome
            case .bodyweightOnly: return ex.equipmentTag.worksBodyweightOnly
            }
        }

        func equipmentQualityBonus(_ ex: PoolExercise) -> Int {
            switch equipment {
            case .fullGym:
                // A full-gym user should get gym-caliber compound/machine/
                // cable/free-weight loading — bodyweight-only entries exist
                // as a fallback for people with nothing else, not a
                // competitive pick when a barbell or machine is available.
                return ex.equipmentTag == .bodyweight ? 0 : 3
            case .homeDumbbells:
                return (ex.equipmentTag == .dumbbell || ex.equipmentTag == .kettlebell) ? 1 : 0
            case .bodyweightOnly:
                return 0
            }
        }

        // Rank of an exercise's minLevel — used to bias toward the more
        // advanced/loadable variant an experienced lifter should actually be
        // doing (e.g. Barbell Back Squat over Goblet Squat once you're past
        // beginner) rather than treating every equipment-eligible option in
        // a pattern as interchangeable. candidates(for:level:) already
        // excludes anything ABOVE the user's level, so this only orders
        // among what's already appropriate.
        func levelRank(_ level: ExperienceLevel) -> Int {
            switch level {
            case .beginner: return 0
            case .intermediate: return 1
            case .advanced: return 2
            }
        }
        func tierMatchBonus(_ ex: PoolExercise) -> Int {
            // Reward exercises whose own minLevel is as close as possible
            // to (but not above) the user's level — i.e. prefer the most
            // advanced appropriate variant, not the most beginner-friendly one.
            levelRank(ex.minLevel)
        }

        func score(_ ex: PoolExercise) -> Int {
            var s = 0
            s += equipmentQualityBonus(ex)
            s += tierMatchBonus(ex)
            if !usedThisWeek.contains(ex.name) { s += 2 }
            if !PersonalizationEngine.isRisky(ex.name, for: injuries) { s += 1 }
            return s
        }

        let notUsedToday = candidates.filter { !usedToday.contains($0.name) }
        let pool = notUsedToday.isEmpty ? candidates : notUsedToday

        // Equipment fit is a hard filter, not a soft nudge — a bodyweight-only
        // user should never actually land on a barbell exercise just because
        // it scored higher on variety. Only fall back to the full pool when
        // this pattern genuinely has no fitting option (a handful of
        // isolation slots — direct bicep/side-delt work — have no bodyweight
        // equivalent worth prescribing).
        let fitting = pool.filter(fitsEquipment)
        let finalPool = fitting.isEmpty ? pool : fitting
        return finalPool.max { score($0) < score($1) }
    }
}
