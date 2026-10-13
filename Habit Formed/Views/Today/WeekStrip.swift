import SwiftUI

/// Seven days as the Today page's date control: the weekday, the date, and a
/// dot for how that day went. The selected day shows its count ("2/6") in
/// place of the dot, so the page needs no separate progress line. Drawn
/// straight on the canvas, so it reads as navigation rather than another card.
struct WeekStrip: View {
    /// Seven summaries, oldest first.
    let summaries: [DaySummary]
    @Binding var selectedDate: Date

    var body: some View {
        HStack(spacing: 0) {
            ForEach(summaries) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: DaySummary) -> some View {
        let isSelected = day.date.isSameDay(as: selectedDate)
        let isToday = day.date.isToday

        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            withAnimation(AppMotion.snap) { selectedDate = day.date }
        } label: {
            VStack(spacing: 6) {
                Text(day.date.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(day.date.formatted(.dateTime.day()))
                    .font(.subheadline.weight(isSelected || isToday ? .bold : .medium).monospacedDigit())
                    .foregroundStyle(isSelected ? AppColors.inkOnLight : Color.white.opacity(isToday ? 1 : 0.8))
                    .frame(width: 34, height: 34)
                    .background {
                        // Selection is a hard cut, never an animated fill.
                        if isSelected {
                            Circle().fill(AppColors.solidWhite)
                        } else if isToday {
                            Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        }
                    }
                    .transaction { $0.animation = nil }

                if isSelected && day.expected > 0 {
                    Text("\(day.done)/\(day.expected)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(day.isPerfect ? AppColors.success : Color.white.opacity(0.8))
                        .contentTransition(.numericText(value: Double(day.done)))
                        .frame(height: 12)
                } else {
                    Circle()
                        .fill(dotColor(for: day))
                        .frame(width: 5, height: 5)
                        .frame(height: 12)
                }
            }
            .frame(maxWidth: .infinity, minHeight: AppLayout.minHitTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Green for a perfect day, the progress ramp for a partial one, a faint
    /// dot for a day with nothing logged, and nothing for a day that asked
    /// nothing.
    private func dotColor(for day: DaySummary) -> Color {
        guard day.expected > 0 else { return .clear }
        if day.isPerfect { return AppColors.success }
        if day.done == 0 { return Color.white.opacity(day.date.isToday ? 0 : 0.18) }
        return AppColors.progressColor(for: day.fraction)
    }

    private func accessibilityLabel(for day: DaySummary) -> String {
        let name = day.date.relativeDayName
        guard day.expected > 0 else { return "\(name), nothing due" }
        return "\(name), \(day.done) of \(day.expected) done"
    }
}
