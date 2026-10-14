import Foundation

// MARK: - Day Status

/// What one habit asked of one day, and whether the day answered.
nonisolated enum DayStatus: Sendable, Hashable {
    /// Logged that day.
    case done
    /// Expected today and not logged yet. Today is not over, so it is not a miss.
    case open
    /// Expected on a past day and never logged.
    case missed
    /// A weekly habit on a day it was not logged: weeks are flexible, so a
    /// single day is never a miss. Shown with its week's progress instead.
    case flexible
    /// Nothing asked: an interval countdown still running, or a day before the
    /// habit existed.
    case resting

    /// True when the day counts toward "X of Y done".
    var isExpected: Bool {
        switch self {
        case .done, .open, .missed: return true
        case .flexible, .resting: return false
        }
    }
}

// MARK: - Habit Track

/// A value snapshot of one habit's schedule and log days. The ledger works on
/// these rather than on `Habit`, so its maths is pure and can run anywhere.
nonisolated struct HabitTrack: Sendable {
    let id: UUID
    let frequency: HabitFrequency
    let weeklyTarget: Int
    let intervalDays: Int
    /// Start of the day the habit was created.
    let firstDay: Date
    /// Start of every day with a log.
    let logDays: Set<Date>
    /// `logDays` oldest first, for the interval countdown's binary search;
    /// empty for other cadences, which never look back.
    private let sortedDays: [Date]

    init(id: UUID, frequency: HabitFrequency, weeklyTarget: Int, intervalDays: Int, firstDay: Date, logDays: Set<Date>) {
        self.id = id
        self.frequency = frequency
        self.weeklyTarget = weeklyTarget
        self.intervalDays = intervalDays
        self.firstDay = firstDay
        self.logDays = logDays
        self.sortedDays = frequency == .interval ? logDays.sorted() : []
    }

    func status(on day: Date, today: Date = Date()) -> DayStatus {
        status(onDay: day.startOfDay, today: today.startOfDay)
    }

    /// `status(on:today:)` for dates already at the start of their day, as
    /// every ledger loop has them. Rounding a date to its day is a calendar
    /// call, the one cost that adds up across a long streak walk.
    func status(onDay day: Date, today: Date) -> DayStatus {
        if logDays.contains(day) { return .done }
        if day < firstDay || day > today { return .resting }

        switch frequency {
        case .daily:
            return day == today ? .open : .missed
        case .weekly:
            return .flexible
        case .interval:
            if let last = lastLog(before: day),
               day < last.adding(days: max(intervalDays, 1)).startOfDay {
                return .resting
            }
            return day == today ? .open : .missed
        }
    }

    /// Logs in the calendar week containing `day`, up to and including it.
    func weekCount(through day: Date) -> Int {
        let day = day.startOfDay
        let weekStart = Date.startOfWeek(for: day)
        return logDays.filter { $0 >= weekStart && $0 <= day }.count
    }

    private func lastLog(before day: Date) -> Date? {
        var low = 0
        var high = sortedDays.count
        while low < high {
            let mid = (low + high) / 2
            if sortedDays[mid] < day { low = mid + 1 } else { high = mid }
        }
        return low > 0 ? sortedDays[low - 1] : nil
    }
}

// MARK: - Day Summary

/// How much of one day got done, across every habit.
nonisolated struct DaySummary: Sendable, Identifiable, Hashable {
    let date: Date
    let done: Int
    let expected: Int

    var id: Date { date }

    var fraction: Double {
        expected == 0 ? 0 : Double(done) / Double(expected)
    }

    /// Every expected habit was logged. A day that asked nothing is not
    /// perfect; it is skipped by the streak instead.
    var isPerfect: Bool { expected > 0 && done >= expected }

    var remaining: Int { max(expected - done, 0) }
}

// MARK: - Ledger

/// Day-level maths shared by Today's header, the week strip, History and the
/// daily report, so every surface agrees on "4 of 6" and the streak.
nonisolated enum DayLedger {
    /// How far back a streak walk may go before it gives up.
    private static let lookback = 730

    static func summary(on day: Date, tracks: [HabitTrack], today: Date = Date()) -> DaySummary {
        summary(onDay: day.startOfDay, tracks: tracks, today: today.startOfDay)
    }

    /// `summary(on:tracks:today:)` for dates already at the start of their day.
    private static func summary(onDay day: Date, tracks: [HabitTrack], today: Date) -> DaySummary {
        var done = 0
        var expected = 0
        for track in tracks {
            let status = track.status(onDay: day, today: today)
            if status == .done { done += 1 }
            if status.isExpected { expected += 1 }
        }
        return DaySummary(date: day, done: done, expected: expected)
    }

    /// Consecutive perfect days. Today joins once it is perfect; until then
    /// the run is measured from yesterday, so an unfinished morning never
    /// reads as a broken streak. Days that asked nothing are skipped.
    static func perfectStreak(tracks: [HabitTrack], today: Date = Date()) -> Int {
        guard let earliest = tracks.map(\.firstDay).min() else { return 0 }
        let today = today.startOfDay
        var day = summary(onDay: today, tracks: tracks, today: today).isPerfect
            ? today
            : today.previousDayStart

        var streak = 0
        for _ in 0..<lookback {
            guard day >= earliest else { break }
            let daySummary = summary(onDay: day, tracks: tracks, today: today)
            if daySummary.expected > 0 {
                guard daySummary.isPerfect else { break }
                streak += 1
            }
            day = day.previousDayStart
        }
        return streak
    }

    /// Longest run of perfect days in the lookback window.
    static func bestPerfectStreak(tracks: [HabitTrack], today: Date = Date()) -> Int {
        guard let earliest = tracks.map(\.firstDay).min() else { return 0 }
        let today = today.startOfDay
        let windowStart = max(earliest, today.adding(days: -lookback).startOfDay)
        var day = windowStart
        var best = 0
        var run = 0
        while day <= today {
            let daySummary = summary(onDay: day, tracks: tracks, today: today)
            if daySummary.expected > 0 {
                if daySummary.isPerfect {
                    run += 1
                    best = max(best, run)
                } else if day < today {
                    run = 0
                }
            }
            day = day.nextDayStart
        }
        return best
    }

    /// Summaries for `count` days ending on `last`, oldest first.
    static func summaries(endingOn last: Date, count: Int, tracks: [HabitTrack], today: Date = Date()) -> [DaySummary] {
        let today = today.startOfDay
        var day = last.startOfDay
        var days: [DaySummary] = []
        days.reserveCapacity(count)
        for _ in 0..<count {
            days.append(summary(onDay: day, tracks: tracks, today: today))
            day = day.previousDayStart
        }
        return days.reversed()
    }
}
