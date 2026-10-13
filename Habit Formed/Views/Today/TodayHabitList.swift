import SwiftUI

/// The habits Today shows for the selected day, as tiles or rows. When every
/// habit is logged today the list gives way to one line, since the Done
/// shelf under it already holds them and the header already offers the
/// report.
struct TodayHabitList: View {
    let habits: [Habit]
    let layout: TodayLayout
    let selectedDate: Date
    let isPastDay: Bool
    /// True when today's habits are all on the Done shelf.
    let isAllDone: Bool
    let actions: (Habit) -> HabitActions

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        if isAllDone {
            allDone
        } else {
            switch layout {
            case .tiles:
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(habits) { habit in
                        HabitTileView(habit: habit, selectedDate: selectedDate, isPastDay: isPastDay, actions: actions(habit))
                    }
                }
            case .rows:
                LazyVStack(spacing: 8) {
                    ForEach(habits) { habit in
                        HabitRowView(habit: habit, selectedDate: selectedDate, isPastDay: isPastDay, actions: actions(habit))
                    }
                }
            }
        }
    }

    private var allDone: some View {
        GlassCard {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(AppColors.success)
                Text("Everything is logged today.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
        }
    }
}
