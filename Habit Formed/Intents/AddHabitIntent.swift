import AppIntents
import Foundation
import SwiftData

/// "Add a habit in Habit Formed": asks what the habit is and adds it, reading
/// the name the way the add page does (`HabitGuess`), so "Read 20 minutes"
/// gets a book and a 20 minute timer, "10k steps" checks itself off from
/// Apple Health, and "Gym 3 times a week" is a habit called Gym, 3 a week.
struct AddHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a habit"
    static let description = IntentDescription("Adds a habit from what you call it, like \"Read 20 minutes\" or \"Gym 3 times a week\".")

    @Parameter(title: "Habit", requestValueDialog: "What's the habit?")
    var name: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$name)")
    }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let guess = HabitGuess.read(name)
        guard !guess.title.isEmpty else { throw $name.needsValueError("What's the habit?") }

        let context = Habit_FormedApp.sharedModelContainer.mainContext
        let all = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        var habits = (try? context.fetch(all)) ?? []
        if let same = habits.first(where: { $0.title.localizedCaseInsensitiveCompare(guess.title) == .orderedSame }) {
            return .result(dialog: "You already have \(same.title).")
        }

        var draft = HabitDraft()
        draft.title = guess.title
        draft.symbol = guess.symbol ?? draft.symbol
        draft.colorHex = HabitDraft.freshColor(after: habits.sorted { $0.createdAt < $1.createdAt }.map(\.colorHex))
        draft.apply(guess)
        let habit = draft.makeHabit(sortOrder: (habits.map(\.sortOrder).max() ?? -1) + 1)
        context.insert(habit)
        try? context.save()
        habits.append(habit)
        WidgetSync.refresh(habits: habits, in: context)

        if habit.trackKind == .health {
            return .result(dialog: "Added \(habit.title). It checks itself off from Apple Health.")
        }
        let plan = Self.plan(of: habit)
        let detail = plan.isEmpty ? "" : ", \(plan)"
        return .result(dialog: "Added \(habit.title)\(detail).")
    }

    /// "20 min, 3 times a week", or empty for a plain daily habit.
    private static func plan(of habit: Habit) -> String {
        var parts: [String] = []
        if habit.timerDurationSeconds > 0 { parts.append("\(habit.timerDurationSeconds / 60) min") }
        switch habit.frequency {
        case .daily: break
        case .weekly: parts.append(habit.weeklyTarget == 1 ? "once a week" : "\(habit.weeklyTarget) times a week")
        case .interval: parts.append("every \(habit.intervalDays) days")
        }
        return parts.joined(separator: ", ")
    }
}
