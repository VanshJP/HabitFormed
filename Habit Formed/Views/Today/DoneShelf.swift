import SwiftUI

/// Today's logged habits, stepped out of the grid so the grid shows only
/// what is left. A chip still opens its habit on tap and has the shared menu
/// on a long press, so undo is where it always was.
struct DoneShelf: View {
    let habits: [Habit]
    let actions: (Habit) -> HabitActions

    @Environment(TimerCenter.self) private var timerCenter

    var body: some View {
        GlassSection("Done", meta: "\(habits.count)") {
            FlowLayout(spacing: 8) {
                ForEach(habits) { habit in
                    chip(habit)
                }
            }
        }
    }

    private func chip(_ habit: Habit) -> some View {
        HStack(spacing: 6) {
            Image(systemName: habit.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(habit.color.glyphTone)
            Text(habit.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Image(systemName: "checkmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: AppLayout.minHitTarget)
        .glassCard(cornerRadius: AppLayout.minHitTarget / 2, tint: AppColors.featuredTint(habit.color))
        .contentShape(Capsule())
        .transition(.scale(scale: 0.85).combined(with: .opacity))
        .onTapGesture {
            Haptics.light()
            actions(habit).open()
        }
        .contextMenu {
            HabitContextMenu(habit: habit, selectedDate: Date(), isPastDay: false, actions: actions(habit), timerCenter: timerCenter)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(habit.title), done today")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens history. Long press for options.")
    }
}
