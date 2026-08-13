import Foundation

// MARK: - Exercise Model

struct Exercise: Identifiable, Codable, Hashable {

    let id: String
    let name: String
    let force: String?
    let level: String
    let mechanic: String?
    let equipment: String?
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: [String]
    let category: String
    let images: [String]?

    // Computed post-load by ExerciseCurator, not part of the JSON schema
    var isRecommended: Bool = false

    // MARK: - Codable (exclude isRecommended from JSON encoding/decoding)

    enum CodingKeys: String, CodingKey {
        case id, name, force, level, mechanic, equipment
        case primaryMuscles, secondaryMuscles, instructions
        case category, images
    }

    // MARK: - Image URLs

    static let imageBaseURL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

    var imageURLs: [URL] {
        (images ?? []).compactMap {
            URL(string: Exercise.imageBaseURL + $0)
        }
    }

    var thumbnailURL: URL? {
        imageURLs.first
    }

    /// Original hand-drawn illustration bundled in Assets.xcassets, for the
    /// hand-authored SupplementalExercises entries the free-exercise-db
    /// dataset never had photos for. Named identically to the exercise's
    /// `id` (e.g. "Paya_Pec_Deck") so this needs no separate lookup table.
    var localIllustrationAssetName: String? {
        guard id.hasPrefix("Paya_") else { return nil }
        return id
    }

    // MARK: - Display

    var equipmentLabel: String {
        equipment?.capitalized ?? "Unknown"
    }

    var levelLabel: String {
        level.capitalized
    }

    var primaryMusclesLabel: String {
        primaryMuscles.map { $0.capitalized }.joined(separator: ", ")
    }
}
