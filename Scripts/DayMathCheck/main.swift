// Checks the app's day math (streaks and the day ledger) against brute-force
// versions built on whole calendar days, across time zones, including one
// where clocks change at midnight. Run Scripts/check-day-math.sh.
import Foundation

nonisolated enum HabitFrequency: String, Codable, CaseIterable, Sendable { case daily, weekly, interval }

struct Seeded: RandomNumberGenerator { var s: UInt64; mutating func next() -> UInt64 { s = s &* 6364136223846793005 &+ 1442695040888963407; return s >> 11 } }
typealias Habit = (freq: HabitFrequency, weekly: Int, interval: Int, first: Date, dates: [Date])

func makeData(seed: UInt64, habits: Int = 8, days: Int = 730, rate: Double = 0.8, perfectTail: Int = 0) -> [Habit] {
    var g = Seeded(s: seed)
    let today = Date()
    return (0..<habits).map { h in
        let freq: HabitFrequency = h % 4 == 2 ? .weekly : (h % 4 == 3 ? .interval : .daily)
        var dates: [Date] = []
        for d in 0..<days where d < perfectTail || Double(g.next() % 1000) / 1000 < rate {
            let day = Calendar.current.date(byAdding: .day, value: -d, to: today)!
            dates.append(day.addingTimeInterval(Double(g.next() % 7200) - 3600))
            if g.next() % 10 == 0 { dates.append(day.addingTimeInterval(Double(g.next() % 3000))) } // a second log some days
        }
        return (freq, Int(1 + g.next() % 6), Int(2 + g.next() % 5), Calendar.current.date(byAdding: .day, value: -days, to: today)!, dates.shuffled(using: &g))
    }
}
func newTracks(_ d: [Habit]) -> [HabitTrack] { d.map { HabitTrack(id: UUID(), frequency: $0.freq, weeklyTarget: $0.weekly, intervalDays: $0.interval, firstDay: $0.first.startOfDay, logDays: Set($0.dates.map(\.startOfDay))) } }

// Every zone: the app's day math == a brute-force version on whole calendar days.
func dayNum(_ d: Date) -> Int { Calendar.current.ordinality(of: .day, in: .era, for: d)! }
struct RefTrack { let freq: HabitFrequency; let interval: Int; let first: Int; let days: Set<Int>; let sorted: [Int] }
func refTracks(_ d: [Habit]) -> [RefTrack] { d.map { let s = Set($0.dates.map(dayNum)); return RefTrack(freq: $0.freq, interval: max($0.interval, 1), first: dayNum($0.first), days: s, sorted: s.sorted()) } }
func refSummary(_ t: [RefTrack], _ day: Int, _ today: Int) -> (Int, Int) {
    var done = 0, expected = 0
    for k in t {
        var status = 0 // 0 done 1 open 2 missed 3 flexible 4 resting
        if k.days.contains(day) { status = 0 }
        else if day < k.first || day > today { status = 4 }
        else {
            switch k.freq {
            case .daily: status = day == today ? 1 : 2
            case .weekly: status = 3
            case .interval:
                if let last = k.sorted.last(where: { $0 < day }), day < last + k.interval { status = 4 }
                else { status = day == today ? 1 : 2 }
            }
        }
        if status == 0 { done += 1 }
        if status <= 2 { expected += 1 }
    }
    return (done, expected)
}
func refPerfect(_ t: [RefTrack], _ today: Int) -> Int {
    guard let earliest = t.map(\.first).min() else { return 0 }
    let s0 = refSummary(t, today, today)
    var day = (s0.1 > 0 && s0.0 >= s0.1) ? today : today - 1
    var streak = 0
    for _ in 0..<730 {
        guard day >= earliest else { break }
        let s = refSummary(t, day, today)
        if s.1 > 0 { guard s.0 >= s.1 else { break }; streak += 1 }
        day -= 1
    }
    return streak
}
func refBest(_ t: [RefTrack], _ today: Int) -> Int {
    guard let earliest = t.map(\.first).min() else { return 0 }
    var day = max(earliest, today - 730), best = 0, run = 0
    while day <= today {
        let s = refSummary(t, day, today)
        if s.1 > 0 { if s.0 >= s.1 { run += 1; best = max(best, run) } else if day < today { run = 0 } }
        day += 1
    }
    return best
}
func refDaily(_ dates: [Date], _ today: Int) -> Int {
    let s = Set(dates.map(dayNum)); guard let m = s.max(), m == today || m == today - 1 else { return 0 }
    var n = 0; while s.contains(m - n) { n += 1 }; return n
}
func refInterval(_ dates: [Date], _ interval: Int, _ today: Int) -> Int {
    let i = max(interval, 1); let u = Set(dates.map(dayNum)).sorted(by: >)
    guard let m = u.first, today <= m + i else { return 0 }
    var streak = 1, prev = m
    for d in u.dropFirst() { guard d >= prev - i else { break }; streak += 1; prev = d }
    return streak
}

var checked = 0
for zone in ["America/New_York", "Asia/Kolkata", "America/Santiago", "Australia/Lord_Howe", "UTC"] {
    NSTimeZone.default = TimeZone(identifier: zone)!
    setenv("TZ", zone, 1); tzset(); NSTimeZone.resetSystemTimeZone()
    check(TimeZone.current == TimeZone(identifier: zone)!, "zone not applied: \(TimeZone.current.identifier)")
    for seed in 1...60 {
        let data = makeData(seed: UInt64(seed), habits: 4, days: 120 + seed * 7, rate: [0.3, 0.6, 0.95][seed % 3], perfectTail: seed % 5 == 0 ? 60 : 0)
        let n = newTracks(data), r = refTracks(data)
        let today = Date().addingTimeInterval(Double(seed % 7) * 86400 * -1)
        let t = dayNum(today)
        let newPerfect = DayLedger.perfectStreak(tracks: n, today: today)
        let newBest = DayLedger.bestPerfectStreak(tracks: n, today: today)
        let ns = DayLedger.summaries(endingOn: today, count: 84, tracks: n, today: today).map { [$0.done, $0.expected] }
        check(newPerfect == refPerfect(r, t), "perfectStreak \(zone) \(seed): \(newPerfect) vs \(refPerfect(r, t))")
        check(newBest == refBest(r, t), "best \(zone) \(seed)")
        check(ns == (0..<84).reversed().map { let s = refSummary(r, t - $0, t); return [s.0, s.1] }, "summaries \(zone) \(seed)")
        for h in data {
            let d = Date.calculateStreak(from: h.dates, today: today)
            let w = Date.calculateWeeklyStreak(from: h.dates, target: h.weekly, today: today)
            let i = Date.calculateIntervalStreak(from: h.dates, intervalDays: h.interval, today: today)
            check(d == refDaily(h.dates, t), "daily \(zone) \(seed)")
            check(w == referenceWeekly(h.dates, target: h.weekly, today: today), "weekly \(zone) \(seed)")
            check(i == refInterval(h.dates, h.interval, t), "interval \(zone) \(seed)")
            checked += 1
        }
    }
}
print("equal: \(checked) habit histories across 5 time zones")

func check(_ c: @autoclosure () -> Bool, _ m: @autoclosure () -> String) { if !c() { print("MISMATCH", m()); exit(1) } }

/// The definition, brute force: logs grouped by their real calendar week,
/// walked back a real week at a time.
func referenceWeekly(_ dates: [Date], target: Int, today: Date) -> Int {
    guard target > 0, !dates.isEmpty else { return 0 }
    let counts = Dictionary(grouping: dates.map { Date.startOfWeek(for: $0) }) { $0 }.mapValues(\.count)
    func previous(_ week: Date) -> Date { Date.startOfWeek(for: week.addingTimeInterval(-1)) }
    var week = Date.startOfWeek(for: today.startOfDay)
    if (counts[week] ?? 0) < target { week = previous(week) }
    var streak = 0
    while (counts[week] ?? 0) >= target { streak += 1; week = previous(week) }
    return streak
}
