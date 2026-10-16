import SwiftUI
import SwiftData

/// The habits Today shows for the selected day, as tiles or rows. A done
/// habit stays where it is, filled with its color, so a finished day is a
/// grid of filled squares. On iOS 27 a tile or row lifts and moves: hold
/// it and drag, past the long-press menu. Before that, Arrange habits does it.
struct TodayHabitList: View {
    let habits: [Habit]
    let layout: TodayLayout
    let selectedDate: Date
    let isPastDay: Bool
    /// Habits logged on `selectedDate`, from the page's ledger tracks.
    let doneIDs: Set<UUID>
    let actions: (Habit) -> HabitActions

    @Environment(\.modelContext) private var modelContext

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        switch layout {
        case .tiles:
            LazyVGrid(columns: columns, spacing: 12) {
                cells { habit in
                    HabitTileView(habit: habit, selectedDate: selectedDate, isPastDay: isPastDay, isDone: doneIDs.contains(habit.id), actions: actions(habit))
                }
            }
            .reorderingHabits(habits, in: modelContext)
        case .rows:
            LazyVStack(spacing: 8) {
                cells { habit in
                    HabitRowView(habit: habit, selectedDate: selectedDate, isPastDay: isPastDay, isDone: doneIDs.contains(habit.id), actions: actions(habit))
                }
            }
            .reorderingHabits(habits, in: modelContext)
        }
    }

    @ViewBuilder
    private func cells<Cell: View>(@ViewBuilder _ cell: @escaping (Habit) -> Cell) -> some View {
        if #available(iOS 27, *) {
            ForEach(habits, content: cell).reorderable()
        } else {
            ForEach(habits, content: cell)
        }
    }
}

private extension View {
    /// Writes a drop on Today as the habits' order.
    @ViewBuilder
    func reorderingHabits(_ habits: [Habit], in context: ModelContext) -> some View {
        if #available(iOS 27, *) {
            reorderContainer(for: Habit.self) { difference in
                let moving = IndexSet(difference.sources.compactMap { id in habits.firstIndex { $0.id == id } })
                let destination = switch difference.destination.position {
                case .before(let id): habits.firstIndex { $0.id == id } ?? habits.count
                case .end: habits.count
                }
                Haptics.selection()
                withMotion(AppMotion.settle) {
                    Habit.move(habits, from: moving, to: destination, in: context)
                }
            }
        } else {
            self
        }
    }
}
