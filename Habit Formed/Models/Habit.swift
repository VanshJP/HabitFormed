import Foundation
import SwiftData
import SwiftUI

// MARK: - Frequency

enum HabitFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily:  return "Daily"
        case .weekly: return "Weekly"
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

    var streak: Int { Date.calculateStreak(from: completionDates) }

    var completionsThisWeek: Int {
        let cal = Calendar.current
        return (completions ?? []).filter {
            cal.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
    }
}
