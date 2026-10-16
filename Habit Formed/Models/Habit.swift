import Foundation
import SwiftData
import SwiftUI

// MARK: - Frequency

nonisolated enum HabitFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Log any day; streak counts consecutive days.
    case daily
    /// Goal of N logs per calendar week; streak counts consecutive
    /// weeks that met `Habit.weeklyTarget`.
    case weekly
    /// Once every N days (`Habit.intervalDays`). Logging resets the
    /// countdown, like a lightweight "remind me every few days" cadence.
    case interval

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily:    return "Daily"
        case .weekly:   return "Weekly"
        case .interval: return "Interval"
        }
    }

    /// The add sheet's "How often?" choice.
    var shortLabel: String {
        switch self {
        case .daily:    return "Every day"
        case .weekly:   return "Weekly"
        case .interval: return "Every few days"
        }
    }
}

// MARK: - HealthKit source

nonisolated enum HealthKitSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case steps
    case sleepHours
    case mindfulMinutes
    case activeCalories
    case exerciseMinutes
    case walkingDistance
    case standHours
    case flightsClimbed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:            return "Manual"
        case .steps:           return "Steps"
        case .sleepHours:      return "Sleep"
        case .mindfulMinutes:  return "Mindful"
        case .activeCalories:  return "Calories"
        case .exerciseMinutes: return "Exercise"
        case .walkingDistance: return "Distance"
        case .standHours:      return "Stand"
        case .flightsClimbed:  return "Flights"
        }
    }

    var defaultTarget: Double {
        switch self {
        case .none:            return 1
        case .steps:           return 10_000
        case .sleepHours:      return 7
        case .mindfulMinutes:  return 10
        case .activeCalories:  return 500
        case .exerciseMinutes: return 30
        case .walkingDistance: return 5
        case .standHours:      return 8
        case .flightsClimbed:  return 10
        }
    }

    /// Sensible default when the user picks Weekly as the schedule. Mirrors
    /// Apple Health's recommended weekly numbers where possible
    /// (e.g. 150 exercise minutes / week).
    var weeklyDefaultTarget: Double {
        switch self {
        case .none:            return 1
        case .steps:           return 70_000
        case .sleepHours:      return 49
        case .mindfulMinutes:  return 70
        case .activeCalories:  return 3_500
        case .exerciseMinutes: return 150
        case .walkingDistance: return 35
        case .standHours:      return 56
        case .flightsClimbed:  return 70
        }
    }

    var unitSuffix: String {
        switch self {
        case .none:            return ""
        case .steps:           return " steps"
        case .sleepHours:      return " h"
        case .mindfulMinutes:  return " min"
        case .activeCalories:  return " kcal"
        case .exerciseMinutes: return " min"
        case .walkingDistance: return " km"
        case .standHours:      return " h"
        case .flightsClimbed:  return " floors"
        }
    }

    /// Formats a reading the way a tile and a report print it: "8.2k",
    /// "7h 40m", "32m", with a whole number left whole ("10k", "7h"). Time
    /// reads as hours and minutes, never "7.7h". No unit for counts the
    /// label already names.
    func compactValue(_ value: Double) -> String {
        let oneDecimal = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        switch self {
        case .steps, .activeCalories:
            return value >= 1000 ? "\((value / 1000).formatted(oneDecimal))k" : "\(value.safeRounded)"
        case .sleepHours:
            return (value * 60).minutesAsDuration
        case .standHours:
            // A count of hours stood, not a span of time.
            return "\(value.formatted(oneDecimal))h"
        case .mindfulMinutes, .exerciseMinutes:
            return value.minutesAsDuration
        case .walkingDistance:
            return "\(value.formatted(oneDecimal))km"
        case .flightsClimbed:
            return "\(value.safeRounded)"
        case .none:
            return ""
        }
    }

    /// The unit a `compactValue` does not already carry: " steps" after
    /// "8.2k", nothing after "7h 40m" or "4.8km".
    var compactUnit: String {
        switch self {
        case .steps:          return " steps"
        case .activeCalories: return " kcal"
        case .flightsClimbed: return " floors"
        default:              return ""
        }
    }

    var symbol: String {
        switch self {
        case .none:            return "hand.tap"
        case .steps:           return "figure.walk"
        case .sleepHours:      return "bed.double.fill"
        case .mindfulMinutes:  return "brain.head.profile"
        case .activeCalories:  return "flame.fill"
        case .exerciseMinutes: return "figure.run"
        case .walkingDistance: return "figure.hiking"
        case .standHours:      return "figure.stand"
        case .flightsClimbed:  return "figure.stairs"
        }
    }
}

// MARK: - Track kind

/// How a habit gets logged. Derived from the stored fields, never persisted.
nonisolated enum HabitTrackKind: String, CaseIterable, Identifiable, Sendable {
    case manual
    case timer
    case health

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: return "Check off"
        case .timer:  return "Timer"
        case .health: return "Apple Health"
        }
    }

    var symbol: String {
        switch self {
        case .manual: return "checkmark.circle"
        case .timer:  return "timer"
        case .health: return "heart.fill"
        }
    }
}

// MARK: - Habit

@Model
final class Habit {
    var id: UUID = UUID()
    var title: String = ""
    var symbol: String = "circle.hexagongrid"
    var colorHex: String = "#0D8488"
    var createdAt: Date = Date()
    var sortOrder: Int = 0

    var frequencyRaw: String = HabitFrequency.daily.rawValue
    var weeklyTarget: Int = 5
    /// Cadence for `.interval` habits: log again this many days after
    /// the last completion. SwiftData lightweight migration supplies the
    /// default for existing rows.
    var intervalDays: Int = 3

    var sourceRaw: String = HealthKitSource.none.rawValue
    var targetValue: Double = 1

    var timerDurationSeconds: Int = 0

    // Daily reminder. SwiftData lightweight migration handles new
    // properties as long as they have defaults.
    var reminderEnabled: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    /// When on, the reminder follows the habit's usual log time
    /// (`ReminderTiming`) once there are enough logs; `reminderHour` and
    /// `reminderMinute` are the time until then. Off for habits made before
    /// learning existed, so their set times never move on their own.
    var reminderLearnsTime: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    var completions: [HabitCompletion]? = []

    init(
        title: String,
        symbol: String = "circle.hexagongrid",
        colorHex: String = "#0D8488",
        frequency: HabitFrequency = .daily,
        weeklyTarget: Int = 5,
        intervalDays: Int = 3,
        source: HealthKitSource = .none,
        targetValue: Double = 1,
        timerDurationSeconds: Int = 0,
        reminderEnabled: Bool = false,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        reminderLearnsTime: Bool = false,
        sortOrder: Int = 0
    ) {
        self.title = title
        self.symbol = symbol
        self.colorHex = colorHex
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.frequencyRaw = frequency.rawValue
        self.weeklyTarget = weeklyTarget
        self.intervalDays = intervalDays
        self.sourceRaw = source.rawValue
        self.targetValue = targetValue
        self.timerDurationSeconds = timerDurationSeconds
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.reminderLearnsTime = reminderLearnsTime
    }

    // MARK: - Computed

    var frequency: HabitFrequency { HabitFrequency(rawValue: frequencyRaw) ?? .daily }
    var source: HealthKitSource   { HealthKitSource(rawValue: sourceRaw) ?? .none }
    var color: Color               { Color(hex: colorHex) }

    var completionDates: [Date] { (completions ?? []).map { $0.date } }

    var isCompletedToday: Bool { completion(on: Date()) != nil }

    var todayCompletion: HabitCompletion? { completion(on: Date()) }

    func isCompleted(on date: Date) -> Bool { completion(on: date) != nil }

    /// Logs are checked against the day's range: two calendar calls in all,
    /// not one per log.
    func completion(on date: Date) -> HabitCompletion? {
        let day = date.dayRange
        return (completions ?? []).first { day.contains($0.date) }
    }

    /// Unique logged days, normalised to the start of each day.
    var completionDays: Set<Date> { track.logDays }

    /// Value snapshot for the day ledger, safe to hand to pure code. Rounding
    /// every log to its day is the one slow step (a calendar call per log),
    /// so the snapshot is kept per habit and rebuilt only when its logs, its
    /// schedule or the time zone change.
    var track: HabitTrack {
        let dates = completionDates
        let key = TrackKey(
            logCount: dates.count,
            logSum: dates.reduce(0) { $0 + $1.timeIntervalSinceReferenceDate },
            frequency: frequency,
            weeklyTarget: weeklyTarget,
            intervalDays: intervalDays,
            createdAt: createdAt,
            timeZone: TimeZone.current.identifier
        )
        if let cached = Self.trackCache[id], cached.key == key { return cached.track }
        let track = HabitTrack(
            id: id,
            frequency: frequency,
            weeklyTarget: weeklyTarget,
            intervalDays: intervalDays,
            firstDay: createdAt.startOfDay,
            logDays: Set(dates.map(\.startOfDay))
        )
        Self.trackCache[id] = (key, track)
        return track
    }

    /// What a cached `track` was built from. The sum of the log times
    /// changes with any log added or removed.
    private struct TrackKey: Equatable {
        let logCount: Int
        let logSum: Double
        let frequency: HabitFrequency
        let weeklyTarget: Int
        let intervalDays: Int
        let createdAt: Date
        let timeZone: String
    }

    // ponytail: a plain dictionary, never observed, so reading `track` in a
    // view body cannot invalidate anything. Entries of deleted habits linger;
    // a handful of small sets.
    private static var trackCache: [UUID: (key: TrackKey, track: HabitTrack)] = [:]

    /// How a habit is tracked, for copy and tile layout.
    var trackKind: HabitTrackKind {
        if source != .none { return .health }
        if timerDurationSeconds > 0 { return .timer }
        return .manual
    }

    // MARK: - Reminder time

    /// The minute of the day this habit is usually logged, from logs made on
    /// the day they count for (a backfilled day says nothing about a routine)
    /// and not prompted by a learned reminder. Health habits never learn: sync
    /// writes their logs, not the person.
    var usualLogMinute: Int? {
        guard trackKind != .health else { return nil }
        let times = (completions ?? [])
            .filter { !$0.followedReminder && $0.loggedAt.isSameDay(as: $0.date) }
            .map(\.loggedAt)
            .sorted(by: >)
        return ReminderTiming.typicalMinute(of: times)
    }

    /// The learned reminder time, or nil until there are enough logs.
    var learnedReminderTime: ReminderTime? {
        usualLogMinute.map { ReminderTiming.reminder(beforeTypical: $0) }
    }

    /// When the reminder actually fires.
    var reminderFireTime: ReminderTime {
        if reminderLearnsTime, let learned = learnedReminderTime { return learned }
        return ReminderTime(hour: reminderHour, minute: reminderMinute)
    }

    // MARK: - Logging

    /// Logs `day` unless it already has a log, and returns the new entry.
    /// Every log path (slide, detail, calendar backfill, timer, widget,
    /// reminder action) goes through here so a day never holds two
    /// completions. `time` is when it happened; the widget passes its tap.
    @discardableResult
    func log(on day: Date = Date(), at time: Date = Date(), in context: ModelContext) -> HabitCompletion? {
        guard completion(on: day) == nil else { return nil }
        // Read before this log can move it.
        let learned = reminderEnabled && reminderLearnsTime ? learnedReminderTime : nil
        let entry = HabitCompletion(date: day, value: targetValue, habit: self)
        entry.loggedAt = time
        entry.followedReminder = Self.follows(learned, at: time, on: day)
        context.insert(entry)
        try? context.save()
        return entry
    }

    /// True when `time`, on `day` itself, falls within
    /// `ReminderTiming.leadMinutes` after a learned reminder.
    private static func follows(_ reminder: ReminderTime?, at time: Date, on day: Date) -> Bool {
        guard let reminder, time.isSameDay(as: day) else { return false }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let since = (parts.hour ?? 0) * 60 + (parts.minute ?? 0) - reminder.minuteOfDay
        return since >= 0 && since < ReminderTiming.leadMinutes
    }

    /// Removes every log on `day`.
    func removeLog(on day: Date, in context: ModelContext) {
        let range = day.dayRange
        for entry in (completions ?? []) where range.contains(entry.date) {
            context.delete(entry)
        }
        try? context.save()
    }

    // MARK: - Order

    /// Moves the habits at `offsets` to `destination` in Today's order,
    /// writing only the places that changed. Arrange habits and a lift on
    /// Today both go through here.
    static func move(_ habits: [Habit], from offsets: IndexSet, to destination: Int, in context: ModelContext) {
        var ordered = habits
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, habit) in ordered.enumerated() where habit.sortOrder != index {
            habit.sortOrder = index
        }
        try? context.save()
    }

    // MARK: - Schedule-aware streaks

    /// Consecutive-day streak. Only meaningful for `.daily`; use
    /// `displayStreak` for the number shown in UI.
    var streak: Int { Date.calculateStreak(from: completionDates) }

    /// Streak measured in the habit's own cadence: consecutive days for
    /// daily, consecutive weeks meeting the weekly target for weekly,
    /// and consecutive on-time cycles for interval habits.
    var displayStreak: Int {
        switch frequency {
        case .daily:
            return streak
        case .weekly:
            return Date.calculateWeeklyStreak(from: completionDates, target: weeklyTarget)
        case .interval:
            return Date.calculateIntervalStreak(from: completionDates, intervalDays: intervalDays)
        }
    }

    /// Unit label paired with `displayStreak` ("day", "wk", "cycle").
    var streakUnitLabel: String { streakUnit(for: displayStreak) }

    func streakUnit(for count: Int) -> String {
        switch frequency {
        case .daily:    return count == 1 ? "day" : "days"
        case .weekly:   return count == 1 ? "wk" : "wks"
        case .interval: return count == 1 ? "cycle" : "cycles"
        }
    }

    /// `displayStreak` as it stood at the end of `day`, ignoring later logs.
    /// The daily report for a past day uses this.
    func displayStreak(asOf day: Date) -> Int {
        let end = day.startOfDay
        let limit = day.dayRange.upperBound
        let dates = completionDates.filter { $0 < limit }
        switch frequency {
        case .daily:
            return Date.calculateStreak(from: dates, today: end)
        case .weekly:
            return Date.calculateWeeklyStreak(from: dates, target: weeklyTarget, today: end)
        case .interval:
            return Date.calculateIntervalStreak(from: dates, intervalDays: intervalDays, today: end)
        }
    }

    /// One-line human summary of the cadence, e.g. "Daily",
    /// "3× / week", "Every 3 days".
    var scheduleLabel: String {
        switch frequency {
        case .daily:    return "Daily"
        case .weekly:   return "\(weeklyTarget)× / week"
        case .interval: return "Every \(intervalDays) day\(intervalDays == 1 ? "" : "s")"
        }
    }

    // MARK: - Interval countdown

    var lastCompletionDate: Date? {
        completionDates.max()?.startOfDay
    }

    /// First day the habit is due again (last log + cadence), or nil
    /// while the habit has never been logged.
    var nextDueDate: Date? {
        lastCompletionDate?.adding(days: max(intervalDays, 1))
    }

    /// Whole days from today until `nextDueDate`. 0 = due today,
    /// negative = overdue by that many days, nil = never logged.
    var daysUntilDue: Int? {
        guard let due = nextDueDate else { return nil }
        let delta = Calendar.current.dateComponents(
            [.day], from: Date().startOfDay, to: due
        ).day ?? 0
        return delta
    }

    /// True when an interval habit needs a log: never logged, due today,
    /// or overdue.
    var isDue: Bool {
        guard frequency == .interval else { return false }
        guard let remaining = daysUntilDue else { return true }
        return remaining <= 0
    }

    /// True when an interval habit asks nothing of the user right now:
    /// mid-countdown with the next due date still ahead and nothing
    /// logged today. Excluded from the Today progress counter.
    var isRestingToday: Bool { restingDaysLeft != nil }

    /// Days left on a resting interval countdown, or nil when the habit can
    /// be logged today.
    var restingDaysLeft: Int? {
        guard frequency == .interval,
              !isCompletedToday,
              let remaining = daysUntilDue, remaining > 0 else { return nil }
        return remaining
    }

    var completionsThisWeek: Int {
        completionsInWeek(of: Date()).count
    }

    /// Sum of the `value` field across this week's completions. Useful for
    /// manual weekly habits where each log carries a numeric amount.
    var valueThisWeek: Double {
        completionsInWeek(of: Date()).reduce(0) { $0 + $1.value }
    }

    /// True once any completion exists within the same calendar week as
    /// `date`. Weekly habits use this in place of `isCompletedToday` so the
    /// "done" glow persists across the week.
    var isCompletedThisWeek: Bool {
        !completionsInWeek(of: Date()).isEmpty
    }

    func completionsInWeek(of date: Date) -> [HabitCompletion] {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: date) else { return [] }
        let range = week.start..<week.end
        return (completions ?? []).filter { range.contains($0.date) }
    }
}
