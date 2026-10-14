import AppIntents
import Foundation
import SwiftData

/// "Log Read in Habit Formed": logs today without opening the app and says
/// where the day stands.
struct LogHabitTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a habit"
    static let description = IntentDescription("Logs a habit for today.")

    @Parameter(title: "Habit")
    var habit: HabitEntity

    init() {}

    init(habit: HabitEntity) {
        self.habit = habit
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = Habit_FormedApp.sharedModelContainer.mainContext
        // Health habits check themselves off from Apple Health; a log by hand
        // would claim a goal the numbers have not reached.
        let id = habit.id
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })
        if let match = try? context.fetch(descriptor).first, match.trackKind == .health {
            return .result(dialog: "\(match.title) logs itself from Apple Health.")
        }

        guard let log = HabitLifecycle.logToday(habitID: habit.id, in: context) else {
            return .result(dialog: "That habit is gone.")
        }
        let title = log.habit.title
        guard log.wasLogged else {
            return .result(dialog: "\(title) is already logged today.")
        }
        let today = DayLedger.summary(on: Date(), tracks: log.habits.map(\.track))
        if today.isPerfect {
            return .result(dialog: "Logged \(title). That's a perfect day.")
        }
        return .result(dialog: "Logged \(title). \(today.done) of \(today.expected) done today.")
    }
}
