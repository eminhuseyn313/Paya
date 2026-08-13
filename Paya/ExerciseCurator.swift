import Foundation

// MARK: - Exercise Curator
// Filters out low-value entries and tags ~100 essential exercises as recommended.
// Curation is based on: EMG hypertrophy studies (Schoenfeld et al.), NSCA/ACSM
// programming guidelines, and coverage of every trainable movement pattern.

enum ExerciseCurator {

    // MARK: - Exclusion Rules

    /// Equipment that indicates niche or non-lifting entries.
    static let excludedEquipment: Set<String> = [
        "foam roll",      // recovery tool, not an exercise
        "exercise ball",  // most stability-ball moves are gimmicky
        "bosu ball"       // balance-toy exercises, rarely useful
    ]

    /// Name substrings (lowercase) indicating advanced calisthenics / gymnastics
    /// that most users can't perform. "expert" level is intentionally NOT
    /// blanket-excluded — some expert lifts are essential (heavy deadlifts, etc).
    static let excludedNameKeywords: [String] = [
        "planche",
        "handstand push",
        "iron cross",
        "human flag",
        "muscle up",
        "one arm push-up",
        "one arm pull-up",
        "one leg pistol",
        "windmill"
    ]

    // MARK: - Recommended Movement Patterns
    // Each pattern matches lowercase-substring in exercise name.
    // Every trainable pattern is covered; goal is ~100 recommended exercises
    // across muscle groups after matching.

    static let recommendedPatterns: [String] = [
        // ── CHEST ──────────────────────────────────────
        "bench press",
        "incline bench press",
        "decline bench press",
        "dumbbell bench press",
        "incline dumbbell bench press",
        "dumbbell fly",
        "incline dumbbell fly",
        "cable crossover",
        "cable fly",
        "machine chest press",
        "pec deck",
        "push-up",
        "dip",

        // ── BACK (LATS + MID) ──────────────────────────
        "pull-up",
        "chin-up",
        "wide-grip lat pulldown",
        "lat pulldown",
        "close-grip pulldown",
        "seated cable row",
        "bent over barbell row",
        "bent-over row",
        "one-arm dumbbell row",
        "t-bar row",
        "chest supported row",
        "face pull",
        "straight-arm pulldown",
        "pullover",

        // ── SHOULDERS ──────────────────────────────────
        "overhead press",
        "military press",
        "seated dumbbell shoulder press",
        "seated barbell shoulder press",
        "arnold press",
        "machine shoulder press",
        "dumbbell lateral raise",
        "cable lateral raise",
        "machine lateral raise",
        "reverse fly",
        "rear delt raise",
        "reverse pec deck",
        "front raise",
        "shrug",

        // ── QUADS / LEGS ───────────────────────────────
        "barbell back squat",
        "barbell squat",
        "front squat",
        "goblet squat",
        "leg press",
        "hack squat",
        "bulgarian split squat",
        "walking lunge",
        "step-up",
        "leg extension",

        // ── POSTERIOR CHAIN ────────────────────────────
        "romanian deadlift",
        "conventional deadlift",
        "sumo deadlift",
        "trap bar deadlift",
        "stiff-legged deadlift",
        "seated leg curl",
        "lying leg curl",
        "hip thrust",
        "glute bridge",
        "good morning",

        // ── BICEPS ─────────────────────────────────────
        "barbell curl",
        "dumbbell curl",
        "hammer curl",
        "preacher curl",
        "cable curl",
        "concentration curl",
        "incline dumbbell curl",
        "spider curl",
        "reverse ez bar curl",
        "reverse cable curl",

        // ── TRICEPS ────────────────────────────────────
        "tricep pushdown",
        "rope pushdown",
        "overhead tricep extension",
        "skull crusher",
        "close-grip bench",
        "tricep dip",
        "kickback",

        // ── CALVES ─────────────────────────────────────
        "standing calf raise",
        "seated calf raise",
        "leg press calf raise",

        // ── CORE ──────────────────────────────────────
        "plank",
        "side plank",
        "crunch",
        "cable crunch",
        "hanging leg raise",
        "hanging knee raise",
        "russian twist",
        "ab wheel",
        "dead bug",
        "bird dog",
        "pallof press",
        "wood chop",

        // ── MOBILITY / WARM-UP ────────────────────────
        "cat cow",
        "child's pose",
        "hip flexor stretch",
        "hamstring stretch",
        "band pull-apart",
        "arm circle",
        "world's greatest stretch",
        "thoracic rotation",
        "scapular pull",

        // ── SUPPLEMENTAL (see SupplementalExercises.swift) ────
        "nordic hamstring curl",
        "bulgarian split squat",
        "chest-supported row",
        "copenhagen plank",
        "suitcase carry",
        "pike push-up",
        "banded lateral walk",
        "clamshell",

        // ── FULL-BODY / FUNCTIONAL ────────────────────
        "kettlebell swing",
        "farmer's walk",
        "farmers walk",
        "clean and press",
        "power clean",

        // ── SMITH MACHINE ──────────────────────────────
        // One of the most common pieces of gym equipment — a guided-bar
        // squat/press rack — but every specific variant name (bench, squat,
        // row, overhead press, calf raise...) was individually absent from
        // the patterns above, making the whole equipment family invisible
        // under the default "recommended only" filter regardless of how it
        // was searched.
        "smith machine"
    ]

    // MARK: - Filter

    static func filter(_ exercises: [Exercise]) -> [Exercise] {
            exercises.filter { ex in
                // No level-based exclusion: 523 of the dataset's 873
                // exercises are tagged "beginner" — that's most machine
                // work, most dumbbell basics, and a lot of exercises people
                // actually search for day-to-day. "Beginner" describes
                // difficulty, not quality; blanket-hiding it made roughly
                // 60% of the library unsearchable for no good reason.
                // Equipment exclusion
                if let equip = ex.equipment?.lowercased(),
                   excludedEquipment.contains(equip) {
                    return false
                }
                // Name keyword exclusion
                let nameLower = ex.name.lowercased()
                for keyword in excludedNameKeywords {
                    if nameLower.contains(keyword) {
                        return false
                    }
                }
                return true
            }
        }

    // MARK: - Mark Recommended

    static func markRecommended(_ exercises: inout [Exercise]) {
        for i in exercises.indices {
            let nameWords = exercises[i].name.lowercased().split(separator: " ")
            for pattern in recommendedPatterns {
                if matchesPattern(pattern, nameWords: nameWords) {
                    exercises[i].isRecommended = true
                    break
                }
            }
        }
    }

    /// A plain substring check (the previous implementation) silently
    /// failed for real exercises whenever the raw dataset's actual name
    /// used a different word order or plural form than the pattern —
    /// "rope pushdown" never matched "triceps pushdown - rope attachment",
    /// "overhead tricep extension" never matched "cable rope overhead
    /// triceps extension" (singular vs. plural "tricep(s)") — so those
    /// exercises silently never appeared as recommended despite genuinely
    /// existing in the database. Matching per-word, order-independent, and
    /// prefix-based (so "tricep" matches "triceps") fixes this whole class
    /// of bug instead of chasing each broken pattern individually.
    private static func matchesPattern(_ pattern: String, nameWords: [Substring]) -> Bool {
        let patternWords = pattern.split(separator: " ")
        return patternWords.allSatisfy { pw in
            nameWords.contains { nw in nw.hasPrefix(pw) || pw.hasPrefix(nw) }
        }
    }

    // MARK: - Combined Apply

    static func curate(_ raw: [Exercise]) -> [Exercise] {
        var curated = filter(raw)
        markRecommended(&curated)
        return curated
    }
}//
//  ExerciseCurator.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//

