import Foundation
import SwiftData

/// A single day's completion record for a habit. `date` is normalized to the
/// start of the calendar day so equality / streak math is straightforward.
@Model
final class HabitCompletion {
    var id: UUID = UUID()
    var date: Date = Date().startOfDay
    var value: Double = 1
    var loggedAt: Date = Date()
    /// What the day's log was about ("Chopin nocturne", "5k in the rain").
    /// Optional context for history and the daily report.
    var note: String = ""

    var habit: Habit?

    init(date: Date = Date(), value: Double = 1, habit: Habit? = nil) {
        self.date = date.startOfDay
        self.value = value
        self.loggedAt = Date()
        self.habit = habit
    }
}
