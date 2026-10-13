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

    static func hours(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1fh", value)
    }

    static func minutes(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return "\(value.safeRounded) min"
    }
}

// MARK: - Text

/// The report as words: the message that rides along with the card in
/// Messages, so a friend reading a notification gets the gist.
nonisolated enum ReportText {
    static func caption(report: DailyReport, options: ReportOptions) -> String {
        var lines: [String] = []

        let who = report.name.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append(who.isEmpty ? "Daily report · \(report.dateText)" : "\(who) · \(report.dateText)")

        var summary = "\(report.done) of \(report.expected) done"
        if report.isPerfect { summary += " · perfect day" }
        if options.showStreaks, report.perfectStreak > 1 {
            summary += " · \(report.perfectStreak) perfect days in a row"
        }
        lines.append(summary)

        if !report.items.isEmpty {
            lines.append(report.items.map { line(for: $0, options: options) }.joined(separator: "\n"))
        }

        if options.showCalories, report.health.eatenKcal != nil || report.health.burnedKcal != nil {
            lines.append("Ate \(ReportFormat.kcal(report.health.eatenKcal)) · burned \(ReportFormat.kcal(report.health.burnedKcal)) · net \(ReportFormat.signedKcal(report.health.netKcal))")
        }

        let note = options.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { lines.append(note) }

        return lines.joined(separator: "\n")
    }

    static func line(for item: DailyReport.Item, options: ReportOptions) -> String {
        var parts: [String] = ["\(mark(for: item.status)) \(item.title)"]
        if let detail = item.detail { parts.append(detail) }
        if options.showStreaks, item.streak > 1 {
            parts.append("\(item.streak) \(item.streakUnit)")
        }
        var line = parts.joined(separator: " · ")
        if options.showNotes, let note = item.note {
            line += " (\(note))"
        }
        return line
    }

    static func mark(for status: DayStatus) -> String {
        switch status {
        case .done: return "✅"
        case .open: return "⬜️"
        case .missed: return "❌"
        case .flexible, .resting: return "➖"
        }
    }
}
