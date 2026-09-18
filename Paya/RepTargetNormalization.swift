import Foundation
import SwiftData

// MARK: - Rep Target Normalization
//
// Established policy for this program: every exercise targets a flat 12
// reps, not a range (see TrainViewModel.defaultReps). That was only ever
// applied to the fallback suggested-rep-count when logging a set —
// the actual stored repMin/repMax on each day's CustomSessionExercise rows
// (inherited from whatever template or repair added them) still varied:
// 8-12, 10-15, 10-12, 8-10, 9-11, checked directly against real data
// before writing this. One-time correction, not a display-only fix, since
// repMin/repMax also drives "hit target" logic elsewhere (plateau/
// weight-increase detection).

enum RepTargetNormalization {

    private static let flagKey = "rep_target_normalization_v1_done"

    @MainActor
    static func normalizeIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        UserDefaults.standard.set(true, forKey: flagKey)

        let descriptor = FetchDescriptor<CustomSessionExercise>()
        let all = (try? context.fetch(descriptor)) ?? []
        var changed = false
        for ex in all where ex.repMin != 12 || ex.repMax != 12 {
            ex.repMin = 12
            ex.repMax = 12
            changed = true
        }
        if changed {
            try? context.save()
        }
    }
}
