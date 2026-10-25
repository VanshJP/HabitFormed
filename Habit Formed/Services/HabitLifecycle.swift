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
    /// Logs today for one habit, the way a slide on its tile does, then
    /// refreshes the widget and reminders. Shared by a reminder's "Log it"
    /// and Siri, which usually run with no window open, so Today's own
    /// resync would not quiet a reminder still due later today.
    @discardableResult
    static func logToday(habitID: UUID, in context: ModelContext) async -> TodayLog? {
        let all = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        guard let habits = try? context.fetch(all),
              let habit = habits.first(where: { $0.id == habitID }) else { return nil }
        let wasLogged = habit.log(on: Date(), in: context) != nil
        if wasLogged {
            WidgetSync.refresh(habits: habits, in: context)
            // ponytail: a fresh service, not the app's; a rebuild removes and
            // re-adds every reminder by id, so racing the app's own sync is harmless.
            await NotificationService().syncReminders(for: habits)
        }
        return TodayLog(habit: habit, wasLogged: wasLogged, habits: habits)
    }

    /// Writes the widget's queued logs, then refreshes the widget and
    /// reminders. `LogHabitIntent` runs it in the app's process, often with
    /// no window open.
    static func writeWidgetLogs(in context: ModelContext) async {
        let all = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        guard let habits = try? context.fetch(all) else { return }
        WidgetSync.refresh(habits: habits, in: context)
        await NotificationService().syncReminders(for: habits)
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
