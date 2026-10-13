import AppIntents
import Foundation
import WidgetKit

/// The widget's log button. It queues the log in the App Group and marks the
/// habit done in the snapshot, so the widget updates at once whichever process
/// runs it; the app writes the real log the next time it is active.
struct LogHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Log habit"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Habit")
    var habitID: String

    @Parameter(title: "Day")
    var day: Date

    init() {}

    init(habitID: UUID, day: Date) {
        self.habitID = habitID.uuidString
        self.day = day
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: habitID) else { return .result() }
        WidgetStore.queue(PendingWidgetLog(habitID: id, day: day, tappedAt: Date()))
        WidgetCenter.shared.reloadAllTimelines()
        await MainActor.run {
            // Only heard when the app process runs the intent; it then writes
            // the log right away instead of on next launch.
            NotificationCenter.default.post(name: .habitLoggedFromWidget, object: nil)
        }
        return .result()
    }
}

extension Notification.Name {
    static let habitLoggedFromWidget = Notification.Name("HabitFormed.loggedFromWidget")
}
