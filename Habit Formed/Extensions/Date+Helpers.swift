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

    /// Calculates the consecutive-day streak ending today (or yesterday — a
    /// streak survives one missed day's worth of grace until the calendar
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
}
