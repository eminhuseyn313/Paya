import Foundation

// MARK: - Load Progress
//
// A real, determinate progress tracker for multi-step async loads — the
// alternative to an indeterminate spinner that gives no sense of whether a
// slow screen is 10% done or about to finish. Callers create one sized to
// however many steps their load actually has, pass it down, and each step
// calls step(_:) as it completes; the view binds a real ProgressView(value:)
// to `fraction` instead of guessing.

@MainActor
@Observable
final class LoadProgress {
    private(set) var completed: Int = 0
    private(set) var total: Int
    private(set) var currentStepLabel: String = ""

    init(total: Int) {
        self.total = max(1, total)
    }

    func step(_ label: String = "") {
        if !label.isEmpty { currentStepLabel = label }
        completed = min(total, completed + 1)
    }

    func reset(total: Int) {
        self.total = max(1, total)
        completed = 0
        currentStepLabel = ""
    }

    var fraction: Double {
        Double(completed) / Double(total)
    }

    var isComplete: Bool { completed >= total }
}
