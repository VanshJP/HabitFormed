import Foundation

/// A time of day for a reminder.
nonisolated struct ReminderTime: Equatable, Sendable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// Wraps any count of minutes into one day, so -30 is 11:30 PM.
    init(minuteOfDay: Int) {
        let wrapped = ((minuteOfDay % 1440) + 1440) % 1440
        hour = wrapped / 60
        minute = wrapped % 60
    }

    var minuteOfDay: Int { hour * 60 + minute }

    /// "9:30 AM", in the person's locale.
    var label: String {
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

/// The days of the week a reminder can keep to, as `Calendar` numbers them
/// (1 is Sunday).
nonisolated enum ReminderDays {
    /// All seven, in the order the person's week runs.
    static func weekOrder(_ calendar: Calendar = .current) -> [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    /// "Mon, Wed, and Fri".
    static func label(_ days: Set<Int>, calendar: Calendar = .current) -> String {
        weekOrder(calendar).filter(days.contains).map { calendar.shortWeekdaySymbols[$0 - 1] }.formatted(.list(type: .and))
    }
}

/// Learns when a habit is usually logged so its reminder can land just
/// before it: someone who waters the plants around 10:00 AM hears about it at
/// 9:30 AM.
nonisolated enum ReminderTiming {
    /// How long before the usual time the reminder fires.
    static let leadMinutes = 30
    /// Logs needed before a learned time replaces the set one.
    static let minimumLogs = 3
    /// Only the latest logs count, so a new routine takes over within weeks.
    static let window = 20

    /// The minute of the day these logs usually happen, or nil while there
    /// are too few. `times` is newest first.
    ///
    /// The median ignores the odd late night. The clock is cut at its widest
    /// empty stretch before taking it, so logs on either side of midnight
    /// (11:50 PM, 12:10 AM) stay together instead of averaging to noon.
    static func typicalMinute(of times: [Date], calendar: Calendar = .current) -> Int? {
        let minutes = times.prefix(window).map { date -> Int in
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }.sorted()
        guard minutes.count >= minimumLogs, let first = minutes.first, let last = minutes.last else { return nil }

        var cut = 0
        var widest = first + 1440 - last
        for index in 1..<minutes.count {
            let gap = minutes[index] - minutes[index - 1]
            if gap > widest {
                widest = gap
                cut = index
            }
        }

        let unrolled = (0..<minutes.count).map { offset -> Int in
            let index = (cut + offset) % minutes.count
            return index < cut ? minutes[index] + 1440 : minutes[index]
        }
        let middle = unrolled.count / 2
        let median = unrolled.count.isMultiple(of: 2)
            ? (unrolled[middle - 1] + unrolled[middle]) / 2
            : unrolled[middle]
        return median % 1440
    }

    /// The weekdays these logs usually fall on: up to `count` of them, the
    /// most logged first, each with at least two logs among the latest
    /// `window`, or nil when none has. `days` are the days the logs count
    /// for, newest first.
    static func usualWeekdays(of days: [Date], count: Int, calendar: Calendar = .current) -> Set<Int>? {
        guard count < 7 else { return nil }
        var tally: [Int: Int] = [:]
        for day in days.prefix(window) {
            tally[calendar.component(.weekday, from: day), default: 0] += 1
        }
        let order = ReminderDays.weekOrder(calendar)
        let ranked = order.filter { tally[$0, default: 0] >= 2 }.sorted { a, b in
            let (logsA, logsB) = (tally[a, default: 0], tally[b, default: 0])
            return logsA != logsB ? logsA > logsB : order.firstIndex(of: a)! < order.firstIndex(of: b)!
        }
        return ranked.isEmpty ? nil : Set(ranked.prefix(count))
    }

    /// The reminder for a usual time: `leadMinutes` earlier, rounded down to
    /// five minutes so it reads like a time a person would pick.
    static func reminder(beforeTypical minute: Int) -> ReminderTime {
        let early = minute - leadMinutes
        let rounded = Int((Double(early) / 5).rounded(.down)) * 5
        return ReminderTime(minuteOfDay: rounded)
    }

    /// The report nudge for days that usually end at `minute` (the day's last
    /// log): `leadMinutes` later, rounded up to five minutes.
    static func reminder(afterTypical minute: Int) -> ReminderTime {
        let late = minute + leadMinutes
        let rounded = Int((Double(late) / 5).rounded(.up)) * 5
        return ReminderTime(minuteOfDay: rounded)
    }
}
