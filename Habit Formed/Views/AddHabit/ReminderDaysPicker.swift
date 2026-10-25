import SwiftUI

/// The days a reminder keeps to: a letter per weekday in the order the
/// person's week runs, the picked ones solid white. None picked is every day.
struct ReminderDaysPicker: View {
    @Binding var days: Set<Int>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ReminderDays.weekOrder(), id: \.self) { weekday in
                dayButton(weekday)
            }
        }
    }

    private func dayButton(_ weekday: Int) -> some View {
        let isOn = days.contains(weekday)
        let calendar = Calendar.current
        return Button {
            Haptics.selection()
            if isOn { days.remove(weekday) } else { days.insert(weekday) }
        } label: {
            Text(calendar.veryShortWeekdaySymbols[weekday - 1])
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isOn ? AnyShapeStyle(AppColors.inkOnLight) : AnyShapeStyle(.primary))
                .frame(width: 36, height: 36)
                .background(Circle().fill(isOn ? AppColors.solidWhite : .clear))
                .controlChrome(in: Circle())
                .frame(maxWidth: .infinity, minHeight: AppLayout.minHitTarget)
                .contentShape(.rect)
                .motion(AppMotion.snap, value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(calendar.weekdaySymbols[weekday - 1])
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
