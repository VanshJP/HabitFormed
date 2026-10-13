import SwiftUI

/// Seven days as the Today page's date control, in one row. Each day is its
/// weekday and date inside a ring that fills as the day's habits are logged
/// and closes green on a perfect day. The selected day sits on a soft fill
/// rather than solid white, so the strip stays quieter than the tiles under
/// it; its count lives in the grid's header. Drawn straight on the canvas, so
/// it reads as navigation rather than another card.
struct WeekStrip: View {
    /// Seven summaries, oldest first.
    let summaries: [DaySummary]
    @Binding var selectedDate: Date

    private let ringSize: CGFloat = 44
    private let lineWidth: CGFloat = 3

    var body: some View {
        HStack(spacing: 0) {
            ForEach(summaries) { day in
                dayCell(day)
            }
        }
        // Seven 44pt rings fill an iPhone row; larger text would push the
        // letters out of them.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private func dayCell(_ day: DaySummary) -> some View {
        let isSelected = day.date.isSameDay(as: selectedDate)
        let isToday = day.date.isToday

        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            withAnimation(AppMotion.snap) { selectedDate = day.date }
        } label: {
            ZStack {
                ring(for: day)

                // Selection is a hard cut, never an animated fill.
                Circle()
                    .fill(Color.white.opacity(isSelected ? 0.16 : 0))
                    .padding(lineWidth + 2)
                    .transaction { $0.animation = nil }

                VStack(spacing: 0) {
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected || isToday ? Color.white.opacity(0.8) : Color.secondary)
                    Text(day.date.formatted(.dateTime.day()))
                        .font(.subheadline.weight(isSelected || isToday ? .bold : .medium).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(isSelected || isToday ? 1 : 0.8))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .frame(width: ringSize, height: ringSize)
            .frame(maxWidth: .infinity, minHeight: AppLayout.minHitTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// A faint track for a day that expected something, filled by the share
    /// logged. A day that asked nothing has no ring at all.
    @ViewBuilder
    private func ring(for day: DaySummary) -> some View {
        if day.expected > 0 {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: day.fraction)
                    .stroke(ringColor(for: day), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(day.done > 0 ? 1 : 0)
            }
            .padding(lineWidth / 2)
            .motion(AppMotion.settle, value: day.done)
        }
    }

    /// Green for a perfect day, the progress ramp for a partial one.
    private func ringColor(for day: DaySummary) -> Color {
        day.isPerfect ? AppColors.success : AppColors.progressColor(for: day.fraction)
    }

    private func accessibilityLabel(for day: DaySummary) -> String {
        let name = day.date.relativeDayName
        guard day.expected > 0 else { return "\(name), nothing due" }
        return "\(name), \(day.done) of \(day.expected) done"
    }
}
