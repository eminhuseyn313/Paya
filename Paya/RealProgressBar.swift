import SwiftUI

// MARK: - Real Progress Bar
//
// A determinate ProgressView bound to an actual LoadProgress tracker,
// instead of the indeterminate spinner every loading screen used before —
// this shows real fraction-complete and which step is currently running,
// so a slow load reads as "3 of 6, fetching weather" instead of an
// unexplained spinner with no sense of whether it's about to finish.

struct RealProgressBar: View {
    var progress: LoadProgress
    var title: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            SwiftUI.ProgressView(value: progress.fraction)
                .frame(maxWidth: 220)
            HStack(spacing: 4) {
                Text("\(progress.completed)/\(progress.total)")
                if !progress.currentStepLabel.isEmpty {
                    Text("· \(progress.currentStepLabel)")
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
