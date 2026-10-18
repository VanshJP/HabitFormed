import Foundation

/// The year so far on one card: every day since January 1, each habit's rate
/// and best run, and the month and weekday that stood out. A plain value,
/// built by `YearReportBuilder`.
nonisolated struct YearReport: Sendable, Hashable {
    /// One habit's year.
    nonisolated struct Row: Sendable, Hashable, Identifiable {
        let id: UUID
        let title: String
        let symbol: String
        let colorHex: String
        /// Days logged inside the year.
        let logs: Int
        /// How often it kept its schedule, 0 to 1: the days it asked for a
        /// daily or interval habit, the weeks that met the target for a
        /// weekly one.
        let rate: Double
        /// The longest run inside the year, in the habit's own unit.
        let bestRun: Int
        /// "days", "wks" or "cycles".
        let runUnit: String
    }

    /// A label and its value: "Best month" and "March, 94%".
    nonisolated struct Highlight: Sendable, Hashable {
        let title: String
        let value: String
    }

    /// One month of the year, as the day grids lay it out.
    nonisolated struct Month: Sendable, Hashable, Identifiable {
        /// 0 for the year's first month.
        let id: Int
        /// "Jan".
        let name: String
        /// "J".
        let initial: String
        /// "January".
        let fullName: String
        let length: Int
        /// Where its first day sits in `days`; past the end for a month
        /// still ahead.
        let offset: Int
        /// Blank cells before its first day, in weeks that start on the
        /// calendar's first weekday.
        let leadingBlanks: Int
    }

    let name: String
    let year: Int
    /// January 1 through the report's last day, oldest first.
    let days: [DaySummary]
    /// Every month of the year, the ones still ahead included.
    let months: [Month]
    /// Best rate first, then most logs.
    let rows: [Row]
    /// The longest run of perfect days inside the year. Days that asked
    /// nothing are skipped, as `DayLedger.bestPerfectStreak` does.
    let bestRun: Int
    let bestMonth: Highlight?
    let bestWeekday: Highlight?

    /// Works out the months, the best run and the highlights from `days`,
    /// which start on January 1.
    init(name: String, year: Int, days: [DaySummary], rows: [Row]) {
        self.name = name
        self.year = year
        self.days = days
        self.rows = rows
        var months: [Month] = []
        if let first = days.first {
            months = YearReport.monthsOfYear(containing: first.date)
        }
        self.months = months
        bestRun = YearReport.longestPerfectRun(in: days)
        bestMonth = YearReport.standoutMonth(days: days, months: months)
        bestWeekday = YearReport.standoutWeekday(days: days)
    }

    var perfectDays: Int { days.reduce(0) { $0 + ($1.isPerfect ? 1 : 0) } }
    var logged: Int { days.reduce(0) { $0 + $1.done } }
    var expected: Int { days.reduce(0) { $0 + $1.expected } }
    var fraction: Double { expected == 0 ? 0 : Double(logged) / Double(expected) }

    /// The report's last day.
    var end: Date { days.last?.date ?? Date() }

    /// "Jan 1 to Oct 18", or "Jan 1" on the year's first day.
    var rangeText: String {
        guard let first = days.first?.date, let last = days.last?.date else { return "" }
        let start = first.formatted(.dateTime.month(.abbreviated).day())
        guard last > first else { return start }
        return "\(start) to \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }

    /// Day `index` of `month` (0 for its first), or nil while it is still
    /// ahead.
    func day(_ index: Int, of month: Month) -> DaySummary? {
        let position = month.offset + index
        return days.indices.contains(position) ? days[position] : nil
    }

    // MARK: - Months

    /// The months of the year `day` falls in, asking the calendar a few
    /// times a month rather than once a day.
    static func monthsOfYear(containing day: Date) -> [Month] {
        let calendar = Calendar.current
        guard let year = calendar.dateInterval(of: .year, for: day) else { return [] }
        let short = calendar.shortStandaloneMonthSymbols
        let narrow = calendar.veryShortStandaloneMonthSymbols
        let wide = calendar.standaloneMonthSymbols

        var months: [Month] = []
        var start = year.start
        var offset = 0
        while start < year.end, months.count < 13 {
            guard let month = calendar.dateInterval(of: .month, for: start) else { break }
            let length = calendar.dateComponents([.day], from: month.start, to: month.end).day ?? 0
            let number = calendar.component(.month, from: month.start) - 1
            let weekday = calendar.component(.weekday, from: month.start)
            let symbol = { (symbols: [String]) in symbols.indices.contains(number) ? symbols[number] : "" }
            months.append(Month(
                id: months.count,
                name: symbol(short),
                initial: symbol(narrow),
                fullName: symbol(wide),
                length: length,
                offset: offset,
                leadingBlanks: (weekday - calendar.firstWeekday + 7) % 7
            ))
            offset += length
            start = month.end
        }
        return months
    }

    // MARK: - Highlights

    private static func longestPerfectRun(in days: [DaySummary]) -> Int {
        var run = 0
        var best = 0
        for day in days where day.expected > 0 {
            if day.isPerfect {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        return best
    }

    /// The month with the best share done, among those with a week of days
    /// that asked something, so a month just begun cannot win on two days.
    private static func standoutMonth(days: [DaySummary], months: [Month]) -> Highlight? {
        let candidates = months.compactMap { month -> Candidate? in
            guard month.offset < days.count else { return nil }
            var done = 0
            var expected = 0
            var asked = 0
            for day in days[month.offset..<min(month.offset + month.length, days.count)] where day.expected > 0 {
                done += day.done
                expected += day.expected
                asked += 1
            }
            guard asked >= 7 else { return nil }
            return Candidate(label: month.fullName, done: done, expected: expected)
        }
        return standout("Best month", among: candidates)
    }

    /// The weekday with the best share done, among those that asked
    /// something at least three times. "Tuesdays, 91%".
    private static func standoutWeekday(days: [DaySummary]) -> Highlight? {
        guard let first = days.first else { return nil }
        let calendar = Calendar.current
        // Days run on one after another, so one call places them all.
        let start = calendar.component(.weekday, from: first.date) - 1
        var done = Array(repeating: 0, count: 7)
        var expected = Array(repeating: 0, count: 7)
        var asked = Array(repeating: 0, count: 7)
        for (index, day) in days.enumerated() where day.expected > 0 {
            let weekday = (start + index) % 7
            done[weekday] += day.done
            expected[weekday] += day.expected
            asked[weekday] += 1
        }
        let symbols = calendar.weekdaySymbols
        let candidates = (0..<7).compactMap { weekday -> Candidate? in
            guard asked[weekday] >= 3, symbols.indices.contains(weekday) else { return nil }
            return Candidate(label: symbols[weekday] + "s", done: done[weekday], expected: expected[weekday])
        }
        return standout("Strongest day", among: candidates)
    }

    private nonisolated struct Candidate {
        let label: String
        let done: Int
        let expected: Int

        var percent: Int { expected == 0 ? 0 : (Double(done) / Double(expected) * 100).safeRounded }
    }

    /// The best of `candidates` by share done, then by logs. Nil unless at
    /// least two compete and the best reads higher than the weakest, since
    /// a tie says nothing.
    private static func standout(_ title: String, among candidates: [Candidate]) -> Highlight? {
        guard candidates.count >= 2,
              let best = candidates.max(by: { ($0.percent, $0.done) < ($1.percent, $1.done) }),
              let weakest = candidates.map(\.percent).min(),
              best.percent > weakest else { return nil }
        return Highlight(title: title, value: "\(best.label), \(best.percent)%")
    }
}

/// Builds a `YearReport` from live habits. Runs on the main actor because it
/// reads SwiftData models; what it returns is a plain value.
enum YearReportBuilder {
    /// - Parameters:
    ///   - habits: every habit, in grid order.
    ///   - end: the report's last day, usually today. The year is the one it
    ///     falls in, from January 1.
    ///   - hidden: habits the person keeps off their cards.
    static func build(habits: [Habit], ending end: Date, name: String, hidden: Set<UUID>) -> YearReport {
        let calendar = Calendar.current
        let end = end.startOfDay
        let today = Date().startOfDay
        let yearStart = calendar.dateInterval(of: .year, for: end)?.start ?? end
        let count = (calendar.dateComponents([.day], from: yearStart, to: end).day ?? 0) + 1
        let included = habits.filter { !hidden.contains($0.id) }
        let tracks = included.map(\.track)
        let days = DayLedger.summaries(endingOn: end, count: max(count, 1), tracks: tracks, today: today)
        // Where January 1 falls in its week, for the weekly habits' weeks.
        let startColumn = (calendar.component(.weekday, from: yearStart) - calendar.firstWeekday + 7) % 7

        var rows: [YearReport.Row] = []
        for (habit, track) in zip(included, tracks) {
            // A habit made after the report's last day has nothing to show.
            guard track.firstDay <= end else { continue }
            let tally = track.frequency == .weekly
                ? weekTally(track, days: days, startColumn: startColumn)
                : dayTally(track, days: days, today: today)
            rows.append(YearReport.Row(
                id: habit.id,
                title: habit.title,
                symbol: habit.symbol,
                colorHex: habit.colorHex,
                logs: tally.logs,
                rate: tally.rate,
                bestRun: tally.bestRun,
                runUnit: habit.streakUnit(for: tally.bestRun)
            ))
        }

        // Best rate first, then most logs, then grid order.
        let ranked = rows.enumerated().sorted { lhs, rhs in
            if lhs.element.rate != rhs.element.rate { return lhs.element.rate > rhs.element.rate }
            if lhs.element.logs != rhs.element.logs { return lhs.element.logs > rhs.element.logs }
            return lhs.offset < rhs.offset
        }

        return YearReport(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            year: calendar.component(.year, from: end),
            days: days,
            rows: ranked.map { $0.element }
        )
    }

    /// What one habit did inside the year.
    private nonisolated struct Tally {
        var logs = 0
        var rate = 0.0
        var bestRun = 0
    }

    /// A daily or interval habit: its share of the days it asked for, and its
    /// longest run of logs each within its cadence of the last (the next day,
    /// for a daily habit).
    nonisolated private static func dayTally(_ track: HabitTrack, days: [DaySummary], today: Date) -> Tally {
        let reach = track.frequency == .interval ? max(track.intervalDays, 1) : 1
        var tally = Tally()
        var asked = 0
        var run = 0
        var lastLog: Int?
        for (index, day) in days.enumerated() {
            let status = track.status(onDay: day.date, today: today)
            if status.isExpected { asked += 1 }
            guard status == .done else { continue }
            tally.logs += 1
            if let lastLog, index - lastLog <= reach {
                run += 1
            } else {
                run = 1
            }
            lastLog = index
            tally.bestRun = max(tally.bestRun, run)
        }
        tally.rate = asked == 0 ? 0 : Double(tally.logs) / Double(asked)
        return tally
    }

    /// A weekly habit: its share of weeks that met the target, and its
    /// longest run of them. A week cut short (by January 1, the habit's
    /// start or the report's last day) counts only once it met the target,
    /// so an unfinished week is never a miss.
    nonisolated private static func weekTally(_ track: HabitTrack, days: [DaySummary], startColumn: Int) -> Tally {
        let target = max(track.weeklyTarget, 1)
        var tally = Tally()
        var weeks = 0
        var met = 0
        var run = 0
        var weekLogs = 0
        var isWhole = false
        for (index, day) in days.enumerated() {
            let column = (startColumn + index) % 7
            if column == 0 {
                weekLogs = 0
                isWhole = day.date >= track.firstDay
            }
            if track.logDays.contains(day.date) {
                tally.logs += 1
                weekLogs += 1
            }
            guard column == 6 || index == days.count - 1 else { continue }
            let reached = weekLogs >= target
            guard reached || (isWhole && column == 6) else { continue }
            weeks += 1
            if reached {
                met += 1
                run += 1
                tally.bestRun = max(tally.bestRun, run)
            } else {
                run = 0
            }
        }
        tally.rate = weeks == 0 ? 0 : Double(met) / Double(weeks)
        return tally
    }
}
