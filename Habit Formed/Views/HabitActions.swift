import SwiftUI

/// Everything a habit surface on Today can ask for. Tiles, rows and done
/// chips take one value so they share a menu and keep the same gestures.
struct HabitActions {
    let open: () -> Void
    let log: () -> Void
    let undoToday: () -> Void
    let togglePastDay: () -> Void
    let edit: () -> Void
    let arrange: () -> Void
    let requestDelete: () -> Void
    let startTimer: () -> Void
    /// Asks before stopping, as the tile's own button and the timer do.
    let requestStopTimer: () -> Void
}

/// The long-press menu every habit surface shares: log or undo the day shown,
/// the timer, then edit, arrange and delete.
struct HabitContextMenu: View {
    let habit: Habit
    let selectedDate: Date
    let isPastDay: Bool
    let actions: HabitActions
    /// Passed in rather than read from the environment, because a context
    /// menu is built outside the view that owns it.
    let timerCenter: TimerCenter

    var body: some View {
        if isPastDay {
            let logged = habit.isCompleted(on: selectedDate)
            Button(logged ? "Remove this day's log" : "Log this day", systemImage: logged ? "minus.circle" : "checkmark.circle") {
                actions.togglePastDay()
            }
        } else if habit.isCompletedToday {
            Button("Undo today's log", systemImage: "arrow.uturn.backward") { actions.undoToday() }
        } else if habit.trackKind != .health {
            // Health checks today off; a log by hand would claim a goal the
            // numbers have not reached. Past days stay fixable above.
            Button("Log today", systemImage: "checkmark.circle") {
                Haptics.success()
                actions.log()
            }
        }
        if habit.timerDurationSeconds > 0, !isPastDay {
            if timerCenter.habitID == habit.id {
                Button("Stop timer", systemImage: "stop.circle", role: .destructive) {
                    actions.requestStopTimer()
                }
            } else {
                Button("Start timer", systemImage: "timer") { actions.startTimer() }
            }
        }
        Divider()
        Button("Edit", systemImage: "pencil") { Haptics.light(); actions.edit() }
        Button("Arrange habits", systemImage: "arrow.up.arrow.down") { Haptics.light(); actions.arrange() }
        Button("Delete", systemImage: "trash", role: .destructive) { Haptics.warning(); actions.requestDelete() }
    }
}
