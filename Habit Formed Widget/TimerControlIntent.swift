import AppIntents
import Foundation

/// Tap target for the Live Activity's pause/resume button. Runs in the
/// host-app process (per `LiveActivityIntent` semantics) so it can
/// reach `TimerCenter` via a plain `NotificationCenter` post.
struct TimerControlIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or Resume Habit Timer"
    static var description = IntentDescription("Toggle the running habit timer.")

    init() {}

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .habitTimerToggleFromActivity,
                object: nil
            )
        }
        return .result()
    }
}

extension Notification.Name {
    static let habitTimerToggleFromActivity = Notification.Name("HabitFormed.toggleTimerFromActivity")
}
