import Foundation
import SwiftUI

@MainActor
@Observable
class ExerciseDatabase {

    static let shared = ExerciseDatabase()

    private(set) var exercises: [Exercise] = []
    private(set) var isLoaded: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var loadError: String? = nil
    private(set) var rawCount: Int = 0

    var showOnlyRecommended: Bool = true

    private(set) var allMuscles: [String] = []
    private(set) var allEquipment: [String] = []
    private(set) var allLevels: [String] = []
    private(set) var allCategories: [String] = []
    private(set) var allForces: [String] = []

    var recommendedCount: Int {
        exercises.filter { $0.isRecommended }.count
    }

    var totalCuratedCount: Int {
        exercises.count
    }

    // MARK: - Load (GCD, guaranteed off main thread)

    func loadIfNeeded() {
        guard !isLoaded, !isLoading else { return }
        load()
    }

    func load() {
        isLoading = true
        loadError = nil

        DispatchQueue.global(qos: .userInitiated).async {

            // Read file
            guard let url = Bundle.main.url(
                forResource: "exercises",
                withExtension: "json"
            ) else {
                DispatchQueue.main.async {
                    self.loadError = "exercises.json not found in app bundle. Add it to the Paya target in Xcode."
                    self.isLoading = false
                }
                return
            }

            // Decode
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                DispatchQueue.main.async {
                    self.loadError = "Failed to read file: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }

            var raw: [Exercise]
            do {
                raw = try JSONDecoder().decode([Exercise].self, from: data)
            } catch {
                DispatchQueue.main.async {
                    self.loadError = "Failed to parse JSON: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }

            // Fill in exercises the bundled dataset predates but this app's
            // own generator already prescribes (see SupplementalExercises.swift).
            raw.append(contentsOf: SupplementalExercises.all)

            // Curate
            let curated = ExerciseCurator.curate(raw)

            // Precompute facets on background thread
            let muscles = Array(Set(curated.flatMap { $0.primaryMuscles })).sorted()
            let equipment = Array(Set(curated.compactMap { $0.equipment })).sorted()
            let levels = Array(Set(curated.map { $0.level })).sorted()
            let categories = Array(Set(curated.map { $0.category })).sorted()
            let forces = Array(Set(curated.compactMap { $0.force })).sorted()

            // Publish results back on main thread
            DispatchQueue.main.async {
                self.exercises = curated
                self.rawCount = raw.count
                self.allMuscles = muscles
                self.allEquipment = equipment
                self.allLevels = levels
                self.allCategories = categories
                self.allForces = forces
                self.isLoaded = true
                self.isLoading = false
            }
        }
    }

    // MARK: - Filter

    struct Filter: Equatable {
        var query: String = ""
        var muscle: String? = nil
        var equipment: String? = nil
        var level: String? = nil
        var category: String? = nil

        var isEmpty: Bool {
            query.isEmpty
                && muscle == nil
                && equipment == nil
                && level == nil
                && category == nil
        }

        var activeCount: Int {
            var count = 0
            if muscle != nil { count += 1 }
            if equipment != nil { count += 1 }
            if level != nil { count += 1 }
            if category != nil { count += 1 }
            return count
        }
    }

    func filtered(_ filter: Filter) -> [Exercise] {
        var results = exercises

        // "Recommended only" is a browsing filter, not a search filter — it
        // exists to keep passive scrolling from being overwhelming, but it
        // has no business hiding an exercise the user is actively typing
        // the name of. Every "I searched for X and it's not there" report
        // so far has been this: the exercise was in the 873-entry database
        // the whole time, just not tagged recommended, so name search
        // silently filtered it out before the query even ran.
        let isActivelySearching = !filter.query.trimmingCharacters(in: .whitespaces).isEmpty
        if showOnlyRecommended && !isActivelySearching {
            results = results.filter { $0.isRecommended }
        }

        if let muscle = filter.muscle {
            results = results.filter { $0.primaryMuscles.contains(muscle) }
        }
        if let equipment = filter.equipment {
            results = results.filter { $0.equipment == equipment }
        }
        if let level = filter.level {
            results = results.filter { $0.level == level }
        }
        if let category = filter.category {
            results = results.filter { $0.category == category }
        }

        let q = filter.query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            results = results.filter {
                $0.name.lowercased().contains(q)
                    || $0.primaryMuscles.contains(where: { $0.lowercased().contains(q) })
                    || ($0.equipment?.lowercased().contains(q) ?? false)
            }
        }

        results.sort { a, b in
            if a.isRecommended != b.isRecommended {
                return a.isRecommended
            }
            return a.name < b.name
        }

        return results
    }

    func exercise(id: String) -> Exercise? {
        exercises.first { $0.id == id }
    }
}
