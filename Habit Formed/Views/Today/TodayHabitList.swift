import SwiftUI

/// The habits Today shows for the selected day, as tiles or rows. A done
/// habit stays where it is, filled with its color, so a finished day is a
/// grid of filled squares.
struct TodayHabitList: View {
    let habits: [Habit]
    let layout: TodayLayout
    let selectedDate: Date
    let isPastDay: Bool
    /// Habits logged on `selectedDate`, from the page's ledger tracks.
    let doneIDs: Set<UUID>
    let actions: (Habit) -> HabitActions

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        switch layout {
        case .tiles:
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(habits) { habit in
                    HabitTileView(habit: habit, selectedDate: selectedDate, isPastDay: isPastDay, isDone: doneIDs.contains(habit.id), actions: actions(habit))
                }
            }
        case .rows:
            LazyVStack(spacing: 8) {
                ForEach(habits) { habit in
                    HabitRowView(habit: habit, selectedDate: selectedDate, isPastDay: isPastDay, isDone: doneIDs.contains(habit.id), actions: actions(habit))
                }
            }
        }
    }
}
