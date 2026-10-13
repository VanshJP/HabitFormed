import Foundation

/// One week on the Sunday recap card: perfect days against the week before,
/// each habit's seven days, and a couple of headlines. A plain value, built
/// by `WeeklyRecapBuilder`.
nonisolated struct WeeklyRecap: Sendable, Hashable {
    /// One habit's week.
    struct Row: Sendable, Hashable, Identifiable {
        let id: UUID
        let title: String
        let colorHex: String
        /// One status per day of the week, oldest first.
        let days: [DayStatus]
    }

    /// A habit and its number: "Read" and "12 days", "Piano" and "+2".
    struct Headline: Sendable, Hashable {
        let title: String
        let value: String
    }

    let name: String
    /// The seven days, oldest first; the last is the recap's day.
    let days: [DaySummary]
    let previousPerfectDays: Int
    let rows: [Row]
    /// The longest running streak at the end of the week.
    let longestStreak: Headline?
    /// The habit logged most more often than the week before.
    let climber: Headline?

    var perfectDays: Int { days.filter(\.isPerfect).count }
    var logged: Int { days.reduce(0) { $0 + $1.done } }
    var expected: Int { days.reduce(0) { $0 + $1.expected } }

    /// "Oct 7 to 13", or "Sep 29 to Oct 5" across a month.
    var rangeText: String {
        guard let first = days.first?.date, let last = days.last?.date else { return "" }
        let sameMonth = Calendar.current.isDate(first, equalTo: last, toGranularity: .month)
        let start = first.formatted(.dateTime.month(.abbreviated).day())
        let end = sameMonth
            ? last.formatted(.dateTime.day())
            : last.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) to \(end)"
    }

    /// How this week compares: "up from 3", "down from 5", "same as last week".
    var trendText: String {
        if perfectDays > previousPerfectDays { return "up from \(previousPerfectDays)" }
        if perfectDays < previousPerfectDays { return "down from \(previousPerfectDays)" }
        return "same as last week"
    }
}

/// Builds a `WeeklyRecap` from live habits. Runs on the main actor because it
/// reads SwiftData models; what it returns is a plain value.
enum WeeklyRecapBuilder {
    /// - Parameters:
    ///   - habits: every habit, in grid order.
    ///   - end: the last day of the week, usually today.
    ///   - hidden: habits the person keeps off their cards.
    static func build(habits: [Habit], ending end: Date, name: String, hidden: Set<UUID>) -> WeeklyRecap {
        let end = end.startOfDay
        let included = habits.filter { !hidden.contains($0.id) }
        let tracks = included.map(\.track)
        let days = DayLedger.summaries(endingOn: end, count: 7, tracks: tracks)
        let previous = DayLedger.summaries(endingOn: end.adding(days: -7), count: 7, tracks: tracks)
        let dates = days.map(\.date)
        let previousDates = previous.map(\.date)

        var rows: [WeeklyRecap.Row] = []
        var longest: (habit: Habit, streak: Int)?
        var climb: (habit: Habit, gain: Int)?
        for (habit, track) in zip(included, tracks) {
            let statuses = dates.map { track.status(on: $0) }
            // A habit made after the week ended has nothing to show.
            guard statuses.contains(where: { $0 != .resting }) else { continue }
            rows.append(WeeklyRecap.Row(id: habit.id, title: habit.title, colorHex: habit.colorHex, days: statuses))

            let streak = habit.displayStreak(asOf: end)
            if streak > (longest?.streak ?? 1) {
                longest = (habit, streak)
            }
            let gain = dates.filter(track.logDays.contains).count - previousDates.filter(track.logDays.contains).count
            if gain > (climb?.gain ?? 0) {
                climb = (habit, gain)
            }
        }

        return WeeklyRecap(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            days: days,
            previousPerfectDays: previous.filter(\.isPerfect).count,
            rows: rows,
            longestStreak: longest.map {
                WeeklyRecap.Headline(title: $0.habit.title, value: "\($0.streak) \($0.habit.streakUnit(for: $0.streak))")
            },
            climber: climb.map { WeeklyRecap.Headline(title: $0.habit.title, value: "+\($0.gain)") }
        )
    }
}
