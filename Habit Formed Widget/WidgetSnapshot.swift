import Foundation

/// What the Home Screen widgets show. The app writes it into the App Group
/// (`WidgetStore`) whenever it changes; the widget extension, which cannot
/// open the habit store, only ever reads it. Compiled into both targets, so
/// it stays Foundation-only.
nonisolated struct WidgetSnapshot: Codable, Sendable, Equatable {
    /// One day of the week row.
    nonisolated struct Day: Codable, Sendable, Equatable {
        var date: Date
        var done: Int
        var expected: Int

        var isPerfect: Bool { expected > 0 && done >= expected }
        var fraction: Double { expected == 0 ? 0 : Double(done) / Double(expected) }
    }

    /// A habit the day asks for, or one that can still be logged.
    nonisolated struct Item: Codable, Sendable, Equatable, Identifiable {
        var id: UUID
        var title: String
        var symbol: String
        var colorHex: String
        var isDone: Bool
        /// Counts toward the day's total (weekly habits on a free day do not).
        var isExpected: Bool
        /// Health habits log themselves, so the widget shows no button.
        var canLog: Bool
    }

    /// Everything one day's widget needs.
    nonisolated struct Page: Codable, Sendable, Equatable {
        var day: Date
        var done: Int
        var expected: Int
        var perfectStreak: Int
        /// The seven days ending on `day`, oldest first.
        var week: [Day]
        /// Unlogged habits first, in grid order, then logged ones.
        var items: [Item]

        var remaining: Int { max(expected - done, 0) }
        var isPerfect: Bool { expected > 0 && done >= expected }

        mutating func markDone(_ habitID: UUID) {
            guard let index = items.firstIndex(where: { $0.id == habitID }), !items[index].isDone else { return }
            items[index].isDone = true
            guard items[index].isExpected else { return }
            done += 1
            if !week.isEmpty {
                week[week.count - 1].done += 1
            }
        }
    }

    var today: Page
    /// Tomorrow as it will look at midnight, so a widget nobody refreshed
    /// overnight still shows the right day in the morning.
    var tomorrow: Page

    /// The page for `date`, or nil when the snapshot is older than that.
    func page(on date: Date, calendar: Calendar = .current) -> Page? {
        if calendar.isDate(today.day, inSameDayAs: date) { return today }
        if calendar.isDate(tomorrow.day, inSameDayAs: date) { return tomorrow }
        return nil
    }

    /// Marks one habit logged on `day`, so a widget tap shows at once.
    mutating func markDone(habitID: UUID, on day: Date, calendar: Calendar = .current) {
        if calendar.isDate(today.day, inSameDayAs: day) { today.markDone(habitID) }
        if calendar.isDate(tomorrow.day, inSameDayAs: day) { tomorrow.markDone(habitID) }
    }
}

/// A log tapped on the widget, waiting for the app to write it.
nonisolated struct PendingWidgetLog: Codable, Sendable, Equatable {
    var habitID: UUID
    var day: Date
    /// When the tap happened, kept so learned reminder times see it.
    var tappedAt: Date
}
