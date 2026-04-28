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

    var habit: Habit?

    init(date: Date = Date(), value: Double = 1, habit: Habit? = nil) {
        self.date = date.startOfDay
        self.value = value
        self.loggedAt = Date()
        self.habit = habit
    }
}
