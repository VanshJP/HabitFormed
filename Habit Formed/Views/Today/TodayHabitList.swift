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
    /// The habit a reorder drag is holding up, so its card paints a plate
    /// rather than glass that would show where it was.
    @State private var liftedID: UUID?

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
            .reorderingHabits(habits, in: modelContext, lifted: $liftedID)
        case .rows:
            LazyVStack(spacing: 8) {
                cells { habit in
                    HabitRowView(habit: habit, selectedDate: selectedDate, isPastDay: isPastDay, isDone: doneIDs.contains(habit.id), actions: actions(habit))
                }
            }
            .reorderingHabits(habits, in: modelContext, lifted: $liftedID)
        }
    }

    @ViewBuilder
    private func cells<Cell: View>(@ViewBuilder _ cell: @escaping (Habit) -> Cell) -> some View {
        if #available(iOS 27, *) {
            ForEach(habits) { habit in
                cell(habit).environment(\.isLifted, habit.id == liftedID)
            }
            .reorderable()
        } else {
            ForEach(habits, content: cell)
        }
    }
}

private extension View {
    /// Writes a drop on Today as the habits' order, and keeps `lifted` on
    /// the habit held up while the drag lasts.
    @ViewBuilder
    func reorderingHabits(_ habits: [Habit], in context: ModelContext, lifted: Binding<UUID?>) -> some View {
        if #available(iOS 27, *) {
            onDragSessionUpdated { session in
                let held: UUID? = switch session.phase {
                case .initial, .active: session.draggedItemIDs(for: UUID.self).first
                default: nil
                }
                if lifted.wrappedValue != held { lifted.wrappedValue = held }
            }
            .reorderContainer(for: Habit.self) { difference in
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
