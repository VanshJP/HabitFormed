import AppIntents
import Foundation
import SwiftData

/// "What's left in Habit Formed": the day's count and what is still open.
struct TodayStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "What's left today"
    static let description = IntentDescription("Says how many habits are done today and which are left.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = Habit_FormedApp.sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        let habits = (try? context.fetch(descriptor)) ?? []
        guard !habits.isEmpty else { return .result(dialog: "No habits yet.") }

        let today = Date()
        let tracks = habits.map(\.track)
        let summary = DayLedger.summary(on: today, tracks: tracks)
        guard summary.expected > 0 else { return .result(dialog: "Nothing to do today.") }
        if summary.isPerfect { return .result(dialog: "All done today.") }

        let left = zip(habits, tracks)
            .filter { $0.1.status(on: today, today: today) == .open }
            .map(\.0.title)
        return .result(dialog: "\(summary.done) of \(summary.expected) done. Left: \(left.formatted(.list(type: .and))).")
    }
}
