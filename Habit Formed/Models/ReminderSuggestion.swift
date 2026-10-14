import Foundation

/// A reminder time for a habit with no logs yet, and the plain reason for it.
/// Two honest signals: what the name says (reading suits the evening) and the
/// person's own routine (just before a habit they already log around then).
/// The habit's own logs take over once learning has enough of them.
nonisolated struct ReminderSuggestion: Equatable, Sendable {
    let time: ReminderTime
    /// "Evenings suit reading", short enough for one caption line.
    let reason: String

    /// How near another habit's usual time must be to anchor to it.
    static let anchorWindow = 90

    /// Nil when the name says nothing about a time of day. `routine` is the
    /// other habits' titles and the minute of the day each is usually logged.
    static func suggest(for title: String, routine: [(title: String, minute: Int)]) -> ReminderSuggestion? {
        let words = title.lowercased().split { !$0.isLetter }
        func says(_ stems: [String]) -> Bool {
            stems.contains { stem in words.contains { $0.hasPrefix(stem) } }
        }
        let activity = activities.first { says($0.stems) }
        let named = dayWords.first { says($0.stems) }
        guard var minute = activity?.minute ?? named?.minute else { return nil }
        // A time word in the name wins unless the activity's own time is
        // already in that part of the day ("Morning run" keeps 7:00 AM).
        if let named, partOfDay(named.minute) != partOfDay(minute) { minute = named.minute }

        let near = routine
            .map { (habit: $0, gap: distance($0.minute, minute)) }
            .filter { $0.gap <= anchorWindow }
            .min { $0.gap < $1.gap }?.habit
        if let near {
            let usual = ReminderTime(minuteOfDay: near.minute).label
            return ReminderSuggestion(
                time: ReminderTiming.reminder(beforeTypical: near.minute),
                reason: "Before you usually log \(near.title) (\(usual))"
            )
        }
        let reason = activity.map { "\(partOfDay(minute)) suit \($0.phrase)" } ?? "As the name says"
        return ReminderSuggestion(time: ReminderTime(minuteOfDay: minute), reason: reason)
    }

    /// Minutes between two times of day the short way round the clock.
    static func distance(_ a: Int, _ b: Int) -> Int {
        let gap = abs(a - b) % 1440
        return min(gap, 1440 - gap)
    }

    private static func partOfDay(_ minute: Int) -> String {
        switch minute {
        case 240..<720: "Mornings"
        case 720..<1020: "Afternoons"
        default: "Evenings"
        }
    }

    // ponytail: word prefixes, first match wins. Add a row when a common
    // name lands nowhere.
    private static let activities: [(stems: [String], phrase: String, minute: Int)] = [
        (["medita", "mindful", "breath"], "meditating", 7 * 60 + 30),
        (["stretch", "yoga"], "stretching", 7 * 60 + 30),
        (["run", "jog"], "a run", 7 * 60),
        (["vitamin", "supplement", "pill", "meds", "medic"], "vitamins", 8 * 60),
        (["journal", "diary"], "journaling", 8 * 60),
        (["plant", "garden"], "watering plants", 9 * 60),
        (["workout", "gym", "exercise", "lift", "train"], "a workout", 18 * 60),
        (["walk"], "a walk", 19 * 60),
        (["study", "studi", "homework", "learn", "revis"], "studying", 19 * 60),
        (["piano", "guitar", "violin", "instrument", "practice"], "practice", 19 * 60),
        (["call"], "calls", 19 * 60),
        (["read"], "reading", 21 * 60 + 30),
        (["floss"], "flossing", 21 * 60 + 30),
        (["skincare"], "skincare", 21 * 60 + 30),
    ]

    private static let dayWords: [(stems: [String], minute: Int)] = [
        (["morning", "breakfast", "wake"], 8 * 60),
        (["lunch", "noon", "midday", "afternoon"], 12 * 60 + 30),
        (["evening", "dinner"], 18 * 60 + 30),
        (["night", "tonight", "bedtime"], 21 * 60 + 30),
    ]
}
