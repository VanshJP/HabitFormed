// Checks the reminder suggester on the add sheet's ideas and a few names
// that should land nowhere. Run Scripts/check-reminder-suggestion.sh.
import Foundation

func check(_ c: Bool, _ m: String) { if !c { print("MISMATCH", m); exit(1) } }
func minute(_ title: String, _ routine: [(title: String, minute: Int)] = []) -> Int? {
    ReminderSuggestion.suggest(for: title, routine: routine)?.time.minuteOfDay
}

let expected: [(String, Int?)] = [
    ("Read", 21 * 60 + 30), ("Workout", 18 * 60), ("Meditate", 7 * 60 + 30), ("Practice piano", 19 * 60),
    ("10k steps", nil), ("Sleep 7 hours", nil), ("Burn 500 kcal", nil), ("Drink water", nil),
    ("Journal", 8 * 60), ("Stretch", 7 * 60 + 30), ("Water the plants", 9 * 60), ("Call family", 19 * 60),
    ("Eat clean", nil), ("Study", 19 * 60), ("Make the bed", nil), ("Pushups", nil),
    ("Journal at night", 21 * 60 + 30), ("Morning run", 7 * 60), ("Lunch walk", 12 * 60 + 30), ("Morning pages", 8 * 60),
]
for (title, want) in expected { check(minute(title) == want, "\(title): \(String(describing: minute(title)))") }

check(ReminderSuggestion.suggest(for: "Read", routine: [])?.reason == "Evenings suit reading", "read reason")
check(ReminderSuggestion.suggest(for: "Journal at night", routine: [])?.reason == "Evenings suit journaling", "night reason")
check(ReminderSuggestion.suggest(for: "Morning pages", routine: [])?.reason == "As the name says", "named reason")

// The routine: 30 min before a habit logged near the name's time, rounded down to five.
let anchored = ReminderSuggestion.suggest(for: "Meditate", routine: [("Workout", 18 * 60), ("Journal", 8 * 60 + 5)])
check(anchored?.time.minuteOfDay == 7 * 60 + 35, "anchor minute")
check(anchored?.reason.hasPrefix("Before you usually log Journal") == true, "anchor reason")
check(minute("Meditate", [("Journal", 20 * 60)]) == 7 * 60 + 30, "far habit ignored")
check(minute("Read", [("Floss", 10)]) == 21 * 60 + 30, "past the window")
check(minute("Journal at night", [("Floss", 22 * 60 + 50)]) == 22 * 60 + 20, "anchor late in the evening")
check(ReminderSuggestion.distance(23 * 60 + 50, 10) == 20, "distance wraps midnight")
check(ReminderSuggestion.distance(0, 720) == 720, "distance half a day")

for (title, _) in expected {
    if let reason = ReminderSuggestion.suggest(for: title, routine: [])?.reason {
        check(reason.count < 50 && !reason.contains("\u{2014}"), "reason copy: \(reason)")
    }
}
print("reminder suggestions match for \(expected.count) names")
