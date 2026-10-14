import Foundation

nonisolated extension Double {
    /// Rounded to a whole number that is always safe to convert. `Int(x)`
    /// traps past `Int.max` or on NaN, and calorie and target fields accept
    /// anything a user types.
    var safeRounded: Int {
        guard isFinite else { return 0 }
        return Int(min(max(rounded(), -1_000_000_000), 1_000_000_000))
    }
}
