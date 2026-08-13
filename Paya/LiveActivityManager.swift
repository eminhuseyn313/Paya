import ActivityKit
import Foundation

// MARK: - Live Activity Manager
//
// Drives the Lock Screen / Dynamic Island tracker during an active training
// session — current exercise, set progress, and rest timer, glanceable
// without unlocking into the app. Mirrors WatchSessionManager's
// push-a-snapshot pattern: TrainViewModel already computes exactly this
// data for the watch app on every state change, so this just forwards the
// same information to ActivityKit.

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<PayaSessionActivityAttributes>?

    var isRunning: Bool { activity != nil }

    private init() {}

    func start(sessionLabel: String, colorHex: String, initialState: PayaSessionActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()

        let attributes = PayaSessionActivityAttributes(sessionLabel: sessionLabel, colorHex: colorHex)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
        } catch {
            activity = nil
        }
    }

    func update(_ state: PayaSessionActivityAttributes.ContentState) {
        guard let activity else { return }
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func end() {
        guard let activity else { return }
        let finalState = activity.content.state
        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
}
