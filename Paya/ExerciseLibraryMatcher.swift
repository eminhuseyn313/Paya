import Foundation

// MARK: - Exercise Library Matcher
// Maps a program/template exercise name to the closest library Exercise
// so users can see form images for any exercise in their plan.

@MainActor
enum ExerciseLibraryMatcher {

    /// Manual aliases for our template names → library-friendly search phrases.
    static let aliases: [String: String] = [
        "goblet squat — heavy": "goblet squat",
        "goblet squat heavy": "goblet squat",
        "incline db press 30°": "incline dumbbell press",
        "seated db shoulder press — 30° back": "seated dumbbell press",
        "seated db shoulder press 30°": "seated dumbbell press",
        "chest-supported row": "chest supported row",
        "lat pulldown — neutral grip": "lat pulldown",
        "lat pulldown neutral": "lat pulldown",
        "face pulls — rope": "face pull",
        "face pulls": "face pull",
        "cable fly — mid height": "cable fly",
        "cable fly mid": "cable crossover",
        "rope pushdown": "triceps pushdown rope",
        "triceps rope pushdown": "triceps pushdown rope",
        "overhead cable tricep extension": "cable overhead triceps extension",
        "overhead cable extension": "cable overhead triceps extension",
        "push-up — weighted or deficit": "push-up",
        "weighted push-up": "push-up",
        "seated cable row — wide grip": "seated cable row",
        "seated cable row wide": "seated cable row",
        "hip thrust — barbell": "barbell hip thrust",
        "one-arm db row": "one-arm dumbbell row",
        "one-arm db row heavy": "one-arm dumbbell row",
        "ez bar curl": "ez-bar curl",
        "leg press heavy": "leg press",
        "hanging knee raise": "hanging knee raise",
        "standing calf raise": "standing calf raise",
        "seated calf raise": "seated calf raise",
        "bulgarian split squat": "bulgarian split squat",
        "romanian deadlift": "romanian deadlift",
        "reverse pec deck": "reverse machine fly",
        "cable lateral raise": "cable lateral raise",
        "hammer curl": "hammer curl",
        "seated leg curl": "seated leg curl",
        "plank": "plank",
        "glute bridge": "glute bridge"
    ]

    private static func normalize(_ s: String) -> [String] {
        let lowered = s.lowercased()
            .replacingOccurrences(of: "—", with: " ")
            .replacingOccurrences(of: "·", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let stopwords: Set<String> = [
            "heavy", "light", "30°", "45°", "mid", "wide", "neutral",
            "grip", "back", "height", "or", "deficit", "the", "a", "db"
        ]
        return lowered
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopwords.contains($0) }
            .map { $0 == "db" ? "dumbbell" : $0 }
    }

    /// Best library match for a program exercise name, or nil if nothing plausible.
    static func match(name: String) -> Exercise? {
        let db = ExerciseDatabase.shared
        guard db.isLoaded, !db.exercises.isEmpty else { return nil }

        // Alias pass first
        let key = name.lowercased()
        let searchName = aliases[key] ?? name

        let queryTokens = Set(normalize(searchName))
        guard !queryTokens.isEmpty else { return nil }

        var best: (exercise: Exercise, score: Double)? = nil

        for exercise in db.exercises {
            let candidateTokens = Set(normalize(exercise.name))
            guard !candidateTokens.isEmpty else { continue }

            let overlap = queryTokens.intersection(candidateTokens).count
            guard overlap > 0 else { continue }

            // Jaccard-ish score, small boost for recommended entries
            var score = Double(overlap) / Double(queryTokens.union(candidateTokens).count)
            if exercise.isRecommended { score += 0.08 }
            // Strong boost for exact containment
            if exercise.name.lowercased().contains(searchName.lowercased()) { score += 0.3 }

            if score > (best?.score ?? 0) {
                best = (exercise, score)
            }
        }

        // Require a minimum plausibility to avoid nonsense matches
        guard let result = best, result.score >= 0.4 else { return nil }
        return result.exercise
    }
}//
//  ExerciseLibraryMatcher.swift
//  Paya
//
//  Created by Emin Huseynzade on 13.07.26.
//

