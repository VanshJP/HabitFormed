import Foundation

/// The Front page layout's headline and the line under it, written from the
/// day's numbers alone: the longest runs kept, what is still open, and the
/// calorie balance when the card shows it. No model: the words follow the
/// numbers, so a headline never claims what the day did not do.
nonisolated enum ReportHeadline {
    /// "Three-day runs hold for Read, Creatine and Mobility".
    static func headline(for report: DailyReport) -> String {
        if report.expected == 0 {
            return report.done > 0 ? "A bonus day: \(words(report.done)) done with nothing due" : "A day of rest"
        }
        if report.isPerfect {
            return report.expected == 1 ? "One for one: the day is done" : "Clean sweep: all \(words(report.expected)) done"
        }
        let done = report.items.filter(\.isDone)
        if let leader = done.max(by: { $0.streak < $1.streak }), leader.streak >= 2 {
            let unit = unitWord(leader.streakUnit)
            let leaders = done.filter { $0.streak == leader.streak && unitWord($0.streakUnit) == unit }
            let run = "\(words(leader.streak))-\(unit)"
            if leaders.count == 1 { return "\(leader.title) keeps a \(run) run" }
            return "\(capitalized(run)) runs hold for \(list(leaders.map(\.title), limit: 3))"
        }
        if report.done > 0 {
            let rest = report.isToday ? "\(words(report.remaining)) to go" : "\(words(report.remaining)) missed"
            return "\(capitalized(words(report.done))) of \(words(report.expected)) done, \(rest)"
        }
        return report.isToday ? "The day is still open" : "A quiet day, nothing logged"
    }

    /// "Red Light Mask, Create Content and Steps (4.5k of 10k steps) still
    /// open as the deficit reaches 1,138 calories."
    static func dek(for report: DailyReport, showsCalories: Bool) -> String {
        let open = report.items.filter { $0.status == .open || $0.status == .missed }
        var sentence: String
        if open.isEmpty {
            sentence = report.done > 0 ? "Every habit logged" : "Nothing was due"
        } else {
            // A Health habit's reading says how close it came.
            let names = open.map { item -> String in
                if item.progress != nil, let detail = item.detail { return "\(item.title) (\(detail))" }
                return item.title
            }
            sentence = "\(list(names, limit: 3)) \(report.isToday ? "still open" : "missed")"
        }
        if showsCalories, let net = report.health.netKcal {
            let amount = abs(net).safeRounded.formatted()
            sentence += net <= 0 ? " as the deficit reaches \(amount) calories" : " with a surplus of \(amount) calories"
        }
        return sentence + "."
    }

    // MARK: - Words

    private static let numbers = [
        "zero", "one", "two", "three", "four", "five", "six",
        "seven", "eight", "nine", "ten", "eleven", "twelve",
    ]

    /// A count as a word up to twelve, as a paper sets it, then digits.
    static func words(_ count: Int) -> String {
        numbers.indices.contains(count) ? numbers[count] : "\(count)"
    }

    /// "day", "week" or "cycle" from a streak's unit ("days", "wks").
    private static func unitWord(_ unit: String) -> String {
        if unit.hasPrefix("wk") { return "week" }
        if unit.hasPrefix("cycle") { return "cycle" }
        return "day"
    }

    private static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "A", "A and B", "A, B and C", or "A, B and 2 more" past `limit`.
    private static func list(_ names: [String], limit: Int) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        if names.count > limit {
            let shown = names.prefix(limit - 1).joined(separator: ", ")
            return "\(shown) and \(names.count - (limit - 1)) more"
        }
        return names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
    }
}
