import Foundation
import SwiftData

/// Teardown that has to happen in order when a habit goes away. Shared by the
/// grid's long-press menu and the detail sheet.
enum HabitLifecycle {
    static func delete(
        _ habit: Habit,
        in context: ModelContext,
        timer: TimerCenter,
        notifications: NotificationService
    ) {
        Haptics.error()
        // Stop the timer before the model is deleted so `TimerCenter.stop()`
        // can dismiss the Live Activity while the snapshot still references a
        // real habit.
        if timer.habitID == habit.id {
            timer.stop()
        }
        // Belt and braces: the reminder signature would resync anyway, but
        // this does not depend on any observer firing.
        notifications.cancelReminders(habitID: habit.id)
        context.delete(habit)
        try? context.save()
    }
}
