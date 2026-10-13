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

    /// The reminder for a usual time: `leadMinutes` earlier, rounded down to
    /// five minutes so it reads like a time a person would pick.
    static func reminder(beforeTypical minute: Int) -> ReminderTime {
        let early = minute - leadMinutes
        let rounded = Int((Double(early) / 5).rounded(.down)) * 5
        return ReminderTime(minuteOfDay: rounded)
    }
}
