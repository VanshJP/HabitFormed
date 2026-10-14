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

    /// The day around this instant, half-open. Checking many dates against
    /// one day costs two calendar calls this way instead of one per date.
    var dayRange: Range<Date> {
        let start = startOfDay
        return start..<start.nextDayStart
    }

    /// The start of the day before, for a date at the start of its day. One
    /// calendar call, and right where a day starts at 1 AM because clocks
    /// change at midnight (adding a day keeps the 1 AM).
    var previousDayStart: Date { addingTimeInterval(-1).startOfDay }

    /// The start of the day after, for a date at the start of its day. Any
    /// day is 23 to 25 hours, so 36 hours in always lands on the next one.
    var nextDayStart: Date { addingTimeInterval(36 * 3600).startOfDay }

    var weekdayShort: String {
        formatted(.dateTime.weekday(.abbreviated))
    }

    /// Calculates the consecutive-day streak ending today (or yesterday;
    /// a streak survives one missed day's worth of grace until the calendar
    /// rolls over). Returns 0 when no completion exists in either window.
    ///
    /// The streak walks the raw dates newest first against day boundaries,
    /// so it costs a calendar call per streak day rather than one per log.
    static func calculateStreak(from dates: [Date], today: Date = Date()) -> Int {
        let sorted = dates.sorted(by: >)
        guard let newest = sorted.first else { return 0 }

        let today = today.startOfDay
        let yesterday = today.previousDayStart
        var day = newest.startOfDay
        guard day == today || day == yesterday else { return 0 }

        var streak = 1
        var previousDay = day.previousDayStart
        for date in sorted.dropFirst() {
            if date >= day { continue }
            guard date >= previousDay else { break }
            streak += 1
            day = previousDay
            previousDay = day.previousDayStart
        }
        return streak
    }

    /// Returns the dates for the trailing `count` days (oldest first),
    /// anchored to the start of today.
    static func trailingDays(_ count: Int, endingOn last: Date = Date()) -> [Date] {
        let end = last.startOfDay
        return (0..<count).reversed().map { end.adding(days: -$0) }
    }

    /// "Today", "Yesterday", or a short weekday and date ("Mon, Oct 12").
    var relativeDayName: String {
        if isToday { return "Today" }
        if isYesterday { return "Yesterday" }
        return formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
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

        // Newest first, counted a week at a time from a moving index, so
        // each week costs one calendar call instead of one per log. Each
        // step asks the calendar for the real week before, since a week can
        // start at 1 AM where clocks change at midnight.
        let calendar = Calendar.current
        let sorted = dates.sorted(by: >)
        var index = 0
        guard var week = calendar.dateInterval(of: .weekOfYear, for: today.startOfDay) else { return 0 }
        func count() -> Int {
            while index < sorted.count, sorted[index] >= week.end { index += 1 }
            var logs = 0
            while index < sorted.count, sorted[index] >= week.start {
                logs += 1
                index += 1
            }
            return logs
        }
        func stepBack() {
            week = calendar.dateInterval(of: .weekOfYear, for: week.start.addingTimeInterval(-1)) ?? week
        }

        // An unfinished current week only joins the chain if it already
        // met the goal; otherwise start counting from last week.
        var logs = count()
        if logs < target {
            stepBack()
            logs = count()
        }

        var streak = 0
        while logs >= target {
            streak += 1
            stepBack()
            logs = count()
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
        let sorted = dates.sorted(by: >)
        guard let newest = sorted.first else { return 0 }
        var previous = newest.startOfDay
        guard today.startOfDay <= previous.adding(days: interval).startOfDay else { return 0 }

        var streak = 1
        for date in sorted.dropFirst() {
            // A second log on a day already counted.
            if date >= previous { continue }
            // Calendar-day comparison rather than raw seconds so DST
            // shifts (23/25h days) can't split an on-time cycle.
            guard date >= previous.adding(days: -interval).startOfDay else { break }
            streak += 1
            previous = date.startOfDay
        }
        return streak
    }
}
