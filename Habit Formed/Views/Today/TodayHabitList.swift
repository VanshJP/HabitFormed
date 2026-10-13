import SwiftUI

/// The habits Today shows for the selected day, as tiles or rows. Once today
/// is perfect one line says so above whatever is still optional (a weekly
/// habit's free day, a resting interval); the Done shelf under it holds the
/// rest and the header already offers the report.
struct TodayHabitList: View {
    let habits: [Habit]
    let layout: TodayLayout
    let selectedDate: Date
    let isPastDay: Bool
    /// True when every habit today expects is logged.
    let isAllDone: Bool
    let actions: (Habit) -> HabitActions

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isAllDone {
                allDone
            }
            if !habits.isEmpty {
                list
            }
        }
    }

    @ViewBuilder
    private var list: some View {
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
