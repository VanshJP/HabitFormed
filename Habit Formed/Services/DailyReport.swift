import Foundation

// MARK: - Daily Report

/// Everything a report card and its caption print, as plain values: built
/// once from the habits, then drawn and written without touching SwiftData.
nonisolated struct DailyReport: Sendable, Hashable {
    struct Item: Sendable, Identifiable, Hashable {
        let id: UUID
        let title: String
        let symbol: String
        let colorHex: String
        let kind: HabitTrackKind
        let status: DayStatus
        /// "25 min", "8.2k of 10k steps", "2/4 this week", "Next in 2 days".
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
    /// Habits the card lists, already filtered by the template.
    let items: [Item]
    /// Every included habit with a status that day, for the text checklist's
    /// "missed" list even when the card shows wins only.
    let allItems: [Item]
    let done: Int
    let expected: Int
    let perfectStreak: Int
    let bestStreak: Int
    /// The 7 days ending on the report day, oldest first.
    let week: [DaySummary]
    let health: DayHealthMetrics

    var fraction: Double { expected == 0 ? 0 : Double(done) / Double(expected) }
    var remaining: Int { max(expected - done, 0) }
    var isPerfect: Bool { expected > 0 && done >= expected }
    var percentText: String { "\((fraction * 100).safeRounded)%" }

    /// The name, or a neutral stand-in so "{name}" never prints blank.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "My day" : trimmed
    }

    /// "Tue, Oct 13".
    var dateText: String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// "today", "yesterday" or the weekday, for running text.
    var dayText: String {
        if date.isToday { return "today" }
        if date.isYesterday { return "yesterday" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    /// One line for the hero: what the day amounted to.
    var verdict: String {
        if expected == 0 { return done > 0 ? "Bonus day" : "Rest day" }
        if isPerfect { return "Perfect day" }
        if isToday {
            return remaining == 1 ? "1 to go" : "\(remaining) to go"
        }
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

    static func grams(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return "\(value.safeRounded)g"
    }
}

// MARK: - Tokens

/// A placeholder a template's words can carry. Expanded when the card is
/// drawn and when the caption is written, so one template stays true every
/// day it is sent.
nonisolated struct ReportToken: Identifiable, Sendable {
    let key: String
    let label: String

    var id: String { key }
    var placeholder: String { "{\(key)}" }

    /// The tokens offered as chips in the editor, most useful first.
    static let all: [ReportToken] = [
        ReportToken(key: "name", label: "Name"),
        ReportToken(key: "date", label: "Date"),
        ReportToken(key: "day", label: "Day"),
        ReportToken(key: "done", label: "Done"),
        ReportToken(key: "total", label: "Total"),
        ReportToken(key: "percent", label: "Percent"),
        ReportToken(key: "left", label: "Left"),
        ReportToken(key: "streak", label: "Streak"),
        ReportToken(key: "best", label: "Best streak"),
        ReportToken(key: "week", label: "Perfect this week"),
        ReportToken(key: "checklist", label: "Checklist"),
        ReportToken(key: "missed", label: "Missed"),
        ReportToken(key: "eaten", label: "Eaten"),
        ReportToken(key: "burned", label: "Burned"),
        ReportToken(key: "net", label: "Net"),
        ReportToken(key: "goal", label: "Goal"),
        ReportToken(key: "steps", label: "Steps"),
        ReportToken(key: "sleep", label: "Sleep"),
        ReportToken(key: "exercise", label: "Exercise"),
    ]
}

// MARK: - Text

/// Writes a report as words: token expansion for the card's lines and the
/// caption that rides along with the image (or goes alone as a text).
nonisolated enum ReportText {
    /// The caption used when a template leaves its own empty.
    static let defaultCaption = "{name} · {date}\n{done} of {total} done ({percent})\n{checklist}"

    /// Expands every `{token}` in `template` against `report`.
    static func expand(_ template: String, report: DailyReport, content: ReportContent) -> String {
        guard template.contains("{") else { return template }
        let values: [String: String] = [
            "name": report.displayName,
            "date": report.dateText,
            "day": report.dayText,
            "weekday": report.date.formatted(.dateTime.weekday(.wide)),
            "done": "\(report.done)",
            "total": "\(report.expected)",
            "left": "\(report.remaining)",
            "percent": report.percentText,
            "streak": "\(report.perfectStreak)",
            "best": "\(report.bestStreak)",
            "week": "\(report.week.filter(\.isPerfect).count)/7",
            "checklist": checklist(report: report, content: content),
            "missed": missedList(report),
            "eaten": ReportFormat.kcal(report.health.eatenKcal),
            "burned": ReportFormat.kcal(report.health.burnedKcal),
            "net": ReportFormat.signedKcal(report.health.netKcal),
            "goal": content.calorieGoal > 0 ? ReportFormat.kcal(content.calorieGoal) : "n/a",
            "steps": ReportFormat.count(report.health.steps),
            "sleep": ReportFormat.hours(report.health.sleepHours),
            "exercise": ReportFormat.minutes(report.health.exerciseMinutes),
            "mindful": ReportFormat.minutes(report.health.mindfulMinutes),
        ]
        var result = template
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }

    /// The message sent with the card, or alone as a text.
    static func caption(report: DailyReport, content: ReportContent) -> String {
        let trimmed = content.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = trimmed.isEmpty ? defaultCaption : content.caption
        return expand(template, report: report, content: content)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// One line per listed habit: a mark, the name, and what the template
    /// asks to show beside it.
    static func checklist(report: DailyReport, content: ReportContent) -> String {
        let items = content.showUnfinished ? report.allItems : report.allItems.filter(\.isDone)
        guard !items.isEmpty else { return "Nothing logged yet." }
        return items.map { line(for: $0, content: content) }.joined(separator: "\n")
    }

    static func line(for item: DailyReport.Item, content: ReportContent) -> String {
        var parts: [String] = ["\(mark(for: item.status)) \(item.title)"]
        if let detail = item.detail { parts.append(detail) }
        if content.showStreaks, item.streak > 1 {
            parts.append("\(item.streak) \(item.streakUnit)")
        }
        var line = parts.joined(separator: " · ")
        if content.showNotes, let note = item.note {
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

    static func missedList(_ report: DailyReport) -> String {
        let names = report.allItems
            .filter { $0.status == .open || $0.status == .missed }
            .map(\.title)
        return names.isEmpty ? "nothing" : names.joined(separator: ", ")
    }
}
