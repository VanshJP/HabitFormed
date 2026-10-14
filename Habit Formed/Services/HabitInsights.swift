import Foundation

/// One habit as the insights see it.
nonisolated struct InsightHabit: Sendable {
    let title: String
    let track: HabitTrack
    /// When logs were made, newest first, counting only logs made on the day
    /// they are for. Empty when the times say nothing (health sync).
    let logTimes: [Date]
}

/// One plain sentence about the person's own logs, with its numbers.
nonisolated struct Insight: Sendable, Hashable, Identifiable {
    /// The habit it is about, or nil when it is about the days.
    let habitID: UUID?
    let text: String

    var id: String { text }
}

/// Patterns in the last eight weeks of finished days, worked out from
/// `DayStatus`, so a weekly habit's free day or a resting interval day is
/// never a miss. Says nothing until there are two weeks of days, then at
/// most three facts, one per habit, in this order: the habit that alone kept
/// days from being perfect, a weekday and weekend gap, a log time that
/// moved, and the hardest weekday.
nonisolated enum HabitInsights {
    static let windowDays = 56
    static let minimumDays = 14
    static let maximumShown = 3

    static func find(in habits: [InsightHabit], today: Date = Date(), calendar: Calendar = .current) -> [Insight] {
        let today = today.startOfDay
        guard let earliest = habits.map(\.track.firstDay).min() else { return [] }

        // Finished days only, newest first: today is still open.
        var days: [Date] = []
        var day = today.previousDayStart
        while days.count < windowDays, day >= earliest {
            days.append(day)
            day = day.previousDayStart
        }
        guard days.count >= minimumDays else { return [] }

        let statuses = habits.map { habit in days.map { habit.track.status(onDay: $0, today: today) } }
        let weekdays = days.map { calendar.component(.weekday, from: $0) }

        let finders: [(Set<UUID>) -> Insight?] = [
            { _ in loneMiss(habits, statuses) },
            { weekendGap(habits, statuses, weekend: days.map(calendar.isDateInWeekend), skip: $0) },
            { timeDrift(habits, today: today, calendar: calendar, skip: $0) },
            { _ in hardestWeekday(statuses, weekdays: weekdays, calendar: calendar) },
        ]
        var found: [Insight] = []
        for finder in finders where found.count < maximumShown {
            if let insight = finder(Set(found.compactMap(\.habitID))) { found.append(insight) }
        }
        return found
    }

    // MARK: - Facts

    /// "Meditate was the only miss on 5 days".
    private static func loneMiss(_ habits: [InsightHabit], _ statuses: [[DayStatus]]) -> Insight? {
        var counts = [Int](repeating: 0, count: habits.count)
        for day in statuses[0].indices {
            let expected = habits.indices.filter { statuses[$0][day].isExpected }
            let missed = expected.filter { statuses[$0][day] == .missed }
            if expected.count > 1, missed.count == 1 { counts[missed[0]] += 1 }
        }
        guard let top = counts.indices.max(by: { counts[$0] < counts[$1] }), counts[top] >= 3 else { return nil }
        return Insight(habitID: habits[top].track.id, text: "\(habits[top].title) was the only miss on \(counts[top]) days")
    }

    /// "Read: 9 of 10 weekdays, but 1 of 4 weekend days".
    private static func weekendGap(_ habits: [InsightHabit], _ statuses: [[DayStatus]], weekend: [Bool], skip: Set<UUID>) -> Insight? {
        var best: (gap: Double, insight: Insight)?
        for (index, habit) in habits.enumerated() where !skip.contains(habit.track.id) {
            var weekdays = Tally()
            var weekends = Tally()
            for (day, status) in statuses[index].enumerated() {
                if weekend[day] { weekends.add(status) } else { weekdays.add(status) }
            }
            guard weekdays.expected >= 8, weekends.expected >= 4 else { continue }
            let gap = abs(weekdays.rate - weekends.rate)
            guard gap >= 0.4, gap > best?.gap ?? 0 else { continue }
            let text = "\(habit.title): \(weekdays.done) of \(weekdays.expected) weekdays, but \(weekends.done) of \(weekends.expected) weekend days"
            best = (gap, Insight(habitID: habit.track.id, text: text))
        }
        return best?.insight
    }

    /// "Journal has moved later: 9:40 PM lately, 8:10 PM before", the last
    /// two weeks' usual log time against the weeks before.
    private static func timeDrift(_ habits: [InsightHabit], today: Date, calendar: Calendar, skip: Set<UUID>) -> Insight? {
        let recentStart = today.adding(days: -14)
        let windowStart = today.adding(days: -windowDays)
        var best: (shift: Int, insight: Insight)?
        for habit in habits where !skip.contains(habit.track.id) {
            let recent = habit.logTimes.filter { $0 >= recentStart }
            let before = habit.logTimes.filter { $0 < recentStart && $0 >= windowStart }
            guard recent.count >= 5, before.count >= 5,
                  let now = ReminderTiming.typicalMinute(of: recent, calendar: calendar),
                  let then = ReminderTiming.typicalMinute(of: before, calendar: calendar)
            else { continue }
            // The short way round the clock, so 11:30 PM to 12:30 AM is an hour.
            let shift = (now - then + 2160) % 1440 - 720
            guard abs(shift) >= 60, abs(shift) > abs(best?.shift ?? 0) else { continue }
            let text = "\(habit.title) has moved \(shift > 0 ? "later" : "earlier"): \(clock(now)) lately, \(clock(then)) before"
            best = (shift, Insight(habitID: habit.track.id, text: text))
        }
        return best?.insight
    }

    /// "Sundays are your hardest day: 48% done, 85% on other days". Needs
    /// four weeks, and no tie for the hardest.
    private static func hardestWeekday(_ statuses: [[DayStatus]], weekdays: [Int], calendar: Calendar) -> Insight? {
        guard weekdays.count >= 28 else { return nil }
        var tallies = [Tally](repeating: Tally(), count: 8)
        for (day, weekday) in weekdays.enumerated() {
            for row in statuses { tallies[weekday].add(row[day]) }
        }
        let week = Array(tallies[1...7])
        guard week.allSatisfy({ $0.expected >= 4 }),
              let low = week.map(\.rate).min(),
              week.filter({ $0.rate == low }).count == 1,
              let hardest = week.firstIndex(where: { $0.rate == low })
        else { return nil }
        var rest = Tally()
        for (index, tally) in week.enumerated() where index != hardest {
            rest.done += tally.done
            rest.expected += tally.expected
        }
        guard rest.rate - low >= 0.25 else { return nil }
        let name = calendar.standaloneWeekdaySymbols[hardest]
        return Insight(habitID: nil, text: "\(name)s are your hardest day: \(percent(low)) done, \(percent(rest.rate)) on other days")
    }

    // MARK: - Helpers

    /// Done out of expected; flexible and resting days are left out.
    private struct Tally {
        var done = 0
        var expected = 0

        var rate: Double { expected == 0 ? 0 : Double(done) / Double(expected) }

        mutating func add(_ status: DayStatus) {
            guard status.isExpected else { return }
            expected += 1
            if status == .done { done += 1 }
        }
    }

    private static func percent(_ rate: Double) -> String {
        "\(Int((rate * 100).rounded()))%"
    }

    /// A minute of the day to the nearest five, as "9:40 PM".
    private static func clock(_ minute: Int) -> String {
        ReminderTime(minuteOfDay: (minute + 2) / 5 * 5).label
    }
}
