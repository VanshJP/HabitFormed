import Foundation
import SwiftData
import SwiftUI

// MARK: - Frequency

enum HabitFrequency: String, Codable, CaseIterable, Identifiable {
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

    /// Short segment-picker title.
    var shortLabel: String {
        switch self {
        case .daily:    return "Daily"
        case .weekly:   return "Per Week"
        case .interval: return "Every N Days"
        }
    }
}

// MARK: - HealthKit source

enum HealthKitSource: String, Codable, CaseIterable, Identifiable {
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
    }

    // MARK: - Computed

    var frequency: HabitFrequency { HabitFrequency(rawValue: frequencyRaw) ?? .daily }
    var source: HealthKitSource   { HealthKitSource(rawValue: sourceRaw) ?? .none }
    var color: Color               { Color(hex: colorHex) }

    var completionDates: [Date] { (completions ?? []).map { $0.date } }

    var isCompletedToday: Bool {
        (completions ?? []).contains { $0.date.isToday }
    }

    var todayCompletion: HabitCompletion? {
        (completions ?? []).first { $0.date.isToday }
    }

    func isCompleted(on date: Date) -> Bool {
        (completions ?? []).contains { $0.date.isSameDay(as: date) }
    }

    func completion(on date: Date) -> HabitCompletion? {
        (completions ?? []).first { $0.date.isSameDay(as: date) }
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

    /// Unit label paired with `displayStreak` ("day", "wk", "log"…).
    var streakUnitLabel: String {
        switch frequency {
        case .daily:    return displayStreak == 1 ? "day" : "days"
        case .weekly:   return displayStreak == 1 ? "wk" : "wks"
        case .interval: return displayStreak == 1 ? "cycle" : "cycles"
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
        completionDates.map { $0.startOfDay }.max()
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
    var isRestingToday: Bool {
        guard frequency == .interval,
              !isCompletedToday,
              let remaining = daysUntilDue, remaining > 0 else { return false }
        return true
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
        let cal = Calendar.current
        return (completions ?? []).filter {
            cal.isDate($0.date, equalTo: date, toGranularity: .weekOfYear)
        }
    }
}
