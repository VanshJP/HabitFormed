import Foundation

nonisolated extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    var weekdayShort: String {
        formatted(.dateTime.weekday(.abbreviated))
    }

    /// Calculates the consecutive-day streak ending today (or yesterday;
    /// a streak survives one missed day's worth of grace until the calendar
    /// rolls over). Returns 0 when no completion exists in either window.
    static func calculateStreak(from dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }

        let unique = Set(dates.map { $0.startOfDay })
        let sorted = unique.sorted(by: >)

        let today = Date().startOfDay
        let yesterday = today.adding(days: -1)

        guard let mostRecent = sorted.first,
              mostRecent == today || mostRecent == yesterday else {
            return 0
        }

        var streak = 1
        var previous = mostRecent

        for date in sorted.dropFirst() {
            let expected = previous.adding(days: -1)
            if date == expected {
                streak += 1
                previous = date
            } else {
                break
            }
        }

        return streak
    }

    /// Returns the dates for the trailing `count` days (oldest first),
    /// anchored to the start of today.
    static func trailingDays(_ count: Int) -> [Date] {
        let today = Date().startOfDay
        return (0..<count).reversed().map { today.adding(days: -$0) }
    }

    /// Start of the calendar week (per `Calendar.current` first weekday)
    /// containing `date`.
    static func startOfWeek(for date: Date) -> Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: date)?.start
            ?? date.startOfDay
    }

    /// Consecutive-week streak where each week logged at least `target`
    /// times. The current week counts once it has met the target;
    /// otherwise the chain is measured back from last week so an
    /// in-progress week doesn't zero the streak mid-way.
    static func calculateWeeklyStreak(
        from dates: [Date], target: Int, today: Date = Date()
    ) -> Int {
        guard target > 0, !dates.isEmpty else { return 0 }

        let counts = Dictionary(grouping: dates.map { startOfWeek(for: $0) }) { $0 }
            .mapValues(\.count)

        var week = startOfWeek(for: today.startOfDay)
        // An unfinished current week only joins the chain if it already
        // met the goal; otherwise start counting from last week.
        if (counts[week] ?? 0) < target {
            week = week.adding(days: -7)
        }

        guard (counts[week] ?? 0) >= target else { return 0 }

        var streak = 0
        while (counts[week] ?? 0) >= target {
            streak += 1
            week = week.adding(days: -7)
        }
        return streak
    }

    /// Streak of consecutive on-time logs for an every-`intervalDays`
    /// cadence: walking backwards through unique log days, each gap must
    /// be ≤ `intervalDays` and the most recent log must still be inside
    /// its window (due today is fine; a day past due breaks the chain).
    static func calculateIntervalStreak(
        from dates: [Date], intervalDays: Int, today: Date = Date()
    ) -> Int {
        let interval = max(intervalDays, 1)
        let sorted = Array(Set(dates.map { $0.startOfDay })).sorted(by: >)
        guard let mostRecent = sorted.first else { return 0 }
        guard today.startOfDay <= mostRecent.adding(days: interval) else { return 0 }

        var streak = 1
        var previous = mostRecent
        for date in sorted.dropFirst() {
            // Calendar-day comparison rather than raw seconds so DST
            // shifts (23/25h days) can't split an on-time cycle.
            guard date >= previous.adding(days: -interval) else { break }
            streak += 1
            previous = date
        }
        return streak
    }
}
