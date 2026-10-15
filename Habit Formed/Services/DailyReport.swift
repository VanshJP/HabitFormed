import Foundation

// MARK: - Daily Report

/// Everything the report card and its text print, as plain values: built once
/// from the habits, then drawn and written without touching SwiftData.
nonisolated struct DailyReport: Sendable, Hashable {
    struct Item: Sendable, Identifiable, Hashable {
        let id: UUID
        let title: String
        let symbol: String
        let colorHex: String
        let status: DayStatus
        /// "25 min", "8.2k of 10k steps", "2/4 this week", "Due today".
        let detail: String?
        let streak: Int
        let streakUnit: String
        let note: String?
        /// The 7 days ending on the report day, oldest first.
        let week: [Bool]

        var isDone: Bool { status == .done }
    }

    let date: Date
    let isToday: Bool
    /// The reporter's name, empty when not set.
    let name: String
    /// The habits on the card, in grid order.
    let items: [Item]
    let done: Int
    let expected: Int
    let perfectStreak: Int
    let health: DayHealthMetrics

    var fraction: Double { expected == 0 ? 0 : Double(done) / Double(expected) }
    var remaining: Int { max(expected - done, 0) }
    var isPerfect: Bool { expected > 0 && done >= expected }
    var percentText: String { "\((fraction * 100).safeRounded)%" }

    /// "Tue, Oct 13".
    var dateText: String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// One line for the hero: what the day amounted to.
    var verdict: String {
        if expected == 0 { return done > 0 ? "Bonus day" : "Rest day" }
        if isPerfect { return "Perfect day" }
        if isToday { return remaining == 1 ? "1 to go" : "\(remaining) to go" }
        return fraction >= 0.5 ? "Solid day" : "Building back"
    }
}

// MARK: - Number formats

nonisolated enum ReportFormat {
    static func kcal(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return "\(value.safeRounded.formatted()) kcal"
    }

    /// Signed, so a deficit reads as one: "-560 kcal", "+120 kcal".
    static func signedKcal(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        let rounded = value.safeRounded
        let sign = rounded > 0 ? "+" : ""
        return "\(sign)\(rounded.formatted()) kcal"
    }

    static func count(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return value >= 10_000
            ? String(format: "%.1fk", value / 1000)
            : value.safeRounded.formatted()
    }

    /// "7h 40m", "45m".
    static func duration(minutes value: Double?) -> String {
        guard let value else { return "n/a" }
        return value.minutesAsDuration
    }

    static func grams(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return "\(value.safeRounded) g"
    }
}
