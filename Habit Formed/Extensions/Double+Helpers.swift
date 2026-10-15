import Foundation

nonisolated extension Double {
    /// Rounded to a whole number that is always safe to convert. `Int(x)`
    /// traps past `Int.max` or on NaN, and calorie and target fields accept
    /// anything a user types.
    var safeRounded: Int {
        guard isFinite else { return 0 }
        return Int(min(max(rounded(), -1_000_000_000), 1_000_000_000))
    }

    /// This many minutes as a clock would say them: "7h 40m", "8h", "45m".
    /// Rounded to the minute first, so 7.999 hours reads "8h", never "7h 60m".
    var minutesAsDuration: String {
        let total = max(safeRounded, 0)
        let hours = total / 60
        let minutes = total % 60
        if hours == 0 { return "\(minutes)m" }
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}
