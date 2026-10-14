// Checks HabitInsights on made-up histories with known answers.
// Run Scripts/check-insights.sh.
import Foundation

nonisolated enum HabitFrequency: String, Sendable { case daily, weekly, interval }

let cal = Calendar.current
let today = Date().startOfDay
func day(_ ago: Int) -> Date { today.adding(days: -ago) }
func at(_ ago: Int, hour: Int) -> Date { cal.date(bySettingHour: hour, minute: 0, second: 0, of: day(ago))! }

func habit(_ title: String, _ days: [Int], created: Int = 70, frequency: HabitFrequency = .daily, hour: (Int) -> Int? = { _ in nil }) -> InsightHabit {
    let track = HabitTrack(id: UUID(), frequency: frequency, weeklyTarget: 3, intervalDays: 2,
                           firstDay: day(created), logDays: Set(days.map(day)))
    return InsightHabit(title: title, track: track, logTimes: days.compactMap { ago in hour(ago).map { at(ago, hour: $0) } })
}

func expect(_ habits: [InsightHabit], _ want: [String], _ name: String) {
    // Times print with a narrow space before PM.
    let got = HabitInsights.find(in: habits, today: today).map { $0.text.replacingOccurrences(of: "\u{202F}", with: " ") }
    guard got == want else { print("FAIL \(name)\n  got  \(got)\n  want \(want)"); exit(1) }
}

let every = Array(0...70)
let weekdaysOnly = every.filter { !cal.isDateInWeekend(day($0)) }
let eightPM = habit("Journal", every) { _ in 20 }
let movedLater = habit("Journal", every) { $0 < 14 ? 22 : 20 }
// One weekday, the same one each week, that "Walk" skips.
let skipDay = cal.component(.weekday, from: day(3))
let walk = habit("Walk", every.filter { cal.component(.weekday, from: day($0)) != skipDay })

expect([habit("Read", Array(0...9), created: 10), eightPM], [], "under two weeks says nothing")
expect([habit("Read", weekdaysOnly, frequency: .weekly), eightPM], [], "a weekly habit's free day is never a miss")
expect([habit("Read", weekdaysOnly), movedLater], [
    "Read was the only miss on 16 days",
    "Journal has moved later: 10:00 PM lately, 8:00 PM before",
], "one fact per habit; weekend tie is no hardest day")
expect([habit("Read", weekdaysOnly), habit("Sing", weekdaysOnly), eightPM], [
    "Read: 40 of 40 weekdays, but 0 of 16 weekend days",
], "two misses a day is no lone miss")
expect([walk, eightPM], [
    "Walk was the only miss on 8 days",
    "\(cal.standaloneWeekdaySymbols[skipDay - 1])s are your hardest day: 50% done, 100% on other days",
], "hardest weekday")
print("insights: 5 histories as expected")
