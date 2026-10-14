import Foundation
import SwiftData

/// What a log made away from the grid did, for a reply.
struct TodayLog {
    let habit: Habit
    /// False when today already had a log.
    let wasLogged: Bool
    /// Every habit in grid order, for the day's count.
    let habits: [Habit]
}

/// Steps that have to happen in order: logging from outside the grid and
/// teardown when a habit goes away.
enum HabitLifecycle {
    /// Logs today for one habit, the way a slide on its tile does, and
    /// refreshes the widget. Shared by a reminder's "Log it" and Siri.
    @discardableResult
    static func logToday(habitID: UUID, in context: ModelContext) -> TodayLog? {
        let all = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        guard let habits = try? context.fetch(all),
              let habit = habits.first(where: { $0.id == habitID }) else { return nil }
        let wasLogged = habit.log(on: Date(), in: context) != nil
        if wasLogged { WidgetSync.refresh(habits: habits, in: context) }
        return TodayLog(habit: habit, wasLogged: wasLogged, habits: habits)
    }


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
