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
        /// When the day's log was made, for a done habit.
        var loggedAt: Date? = nil
        /// A Health habit's reading against its goal, 0 to 1.
        var progress: Double? = nil

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
    let health: DayHealthMetrics

    var fraction: Double { expected == 0 ? 0 : Double(done) / Double(expected) }
    var remaining: Int { max(expected - done, 0) }
    var isPerfect: Bool { expected > 0 && done >= expected }

    /// "Tue, Oct 13".
    var dateText: String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// What the day amounted to, in words: "Perfect day", "3 of 5 done", or
    /// "Rest day" when nothing was asked.
    var verdict: String {
        if expected == 0 { return done > 0 ? "Bonus day" : "Rest day" }
        if isPerfect { return "Perfect day" }
        return "\(done) of \(expected) done"
    }

    /// The count a ring or a number prints: "3/5", or "Rest" on a day that
    /// asked nothing, where "0/0" would read as a failure.
    var countText: String { expected == 0 ? "Rest" : "\(done)/\(expected)" }
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

// MARK: - Health lines

/// One Apple Health number as a label and its value ("Sleep", "7h 44m"), for
/// the layouts that print numbers as lines rather than wells.
nonisolated struct HealthLine: Sendable, Hashable {
    let label: String
    let value: String
    /// A part of the line above it: a kind of workout under Exercise.
    var isPart = false
}

nonisolated extension DayHealthMetrics {
    /// The picked numbers Health has for the day, as lines. A number Health
    /// does not have is left out: a line reading "n/a" looks like a misprint.
    func lines(showing metrics: Set<ReportMetric>) -> [HealthLine] {
        var lines: [HealthLine] = []
        if metrics.contains(.steps), let steps {
            lines.append(HealthLine(label: "Steps", value: ReportFormat.count(steps)))
        }
        if metrics.contains(.exercise), let exerciseMinutes {
            lines.append(HealthLine(label: "Exercise", value: ReportFormat.duration(minutes: exerciseMinutes)))
            for kind in exerciseKinds {
                lines.append(HealthLine(label: kind.name, value: ReportFormat.duration(minutes: kind.minutes), isPart: true))
            }
        }
        if metrics.contains(.sleep), let sleepHours {
            lines.append(HealthLine(label: "Sleep", value: ReportFormat.duration(minutes: sleepHours * 60)))
        }
        if metrics.contains(.mindful), let mindfulMinutes {
            lines.append(HealthLine(label: "Mindful", value: ReportFormat.duration(minutes: mindfulMinutes)))
        }
        if metrics.contains(.calories) {
            if let eatenKcal { lines.append(HealthLine(label: "Eaten", value: ReportFormat.kcal(eatenKcal))) }
            if let burnedKcal { lines.append(HealthLine(label: "Burned", value: ReportFormat.kcal(burnedKcal))) }
            if let netKcal {
                lines.append(HealthLine(label: netKcal <= 0 ? "Deficit" : "Surplus", value: ReportFormat.signedKcal(netKcal)))
            }
        }
        if metrics.contains(.macros) {
            if let protein { lines.append(HealthLine(label: "Protein", value: ReportFormat.grams(protein))) }
            if let carbs { lines.append(HealthLine(label: "Carbs", value: ReportFormat.grams(carbs))) }
            if let fat { lines.append(HealthLine(label: "Fat", value: ReportFormat.grams(fat))) }
        }
        return lines
    }
}
