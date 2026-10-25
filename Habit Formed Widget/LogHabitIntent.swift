import AppIntents
import Foundation
import WidgetKit

/// The widget's log button. It queues the log in the App Group and marks the
/// habit done in the snapshot, so the widget updates at once whichever process
/// runs it. As a `LiveActivityIntent` it runs in the app's process (launched in
/// the background when closed), where `writeInApp` writes the log and rebuilds
/// reminders right away, so one due later today stays quiet. Should the
/// widget's process run it instead, the app writes the queue when next active.
struct LogHabitIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log habit"
    static var isDiscoverable: Bool = false

    /// Set by the app at launch; nil in the widget's process.
    @MainActor static var writeInApp: (() async -> Void)?

    @Parameter(title: "Habit")
    var habitID: String

    @Parameter(title: "Day")
    var day: Date

    init() {}

    init(habitID: UUID, day: Date) {
        self.habitID = habitID.uuidString
        self.day = day
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: habitID) else { return .result() }
        WidgetStore.queue(PendingWidgetLog(habitID: id, day: day, tappedAt: Date()))
        WidgetCenter.shared.reloadAllTimelines()
        // Awaited, so iOS keeps the app awake until the log is written.
        await Self.writeInApp?()
        return .result()
    }
}
