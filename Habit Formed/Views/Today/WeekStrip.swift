import SwiftUI

/// The last seven days as rings, today on the right. Tap a day to browse it;
/// the calendar button reaches anything older.
struct WeekStrip: View {
    /// Seven summaries, oldest first, ending today.
    let summaries: [DaySummary]
    @Binding var selectedDate: Date
    let onOpenCalendar: () -> Void

    var body: some View {
        GlassCard(padding: 6) {
            HStack(spacing: 2) {
                ForEach(summaries) { day in
                    dayCell(day)
                }

                Button {
                    Haptics.light()
                    onOpenCalendar()
                } label: {
                    Image(systemName: "calendar")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36)
                        .frame(maxHeight: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(GlassPressStyle())
                .accessibilityLabel("Browse an older day")
            }
            .fixedSize(horizontal: false, vertical: true)
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
            VStack(spacing: 5) {
                Text(day.date.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isToday ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))

                ProgressRing(fraction: day.fraction, lineWidth: 3) {
                    if day.isPerfect {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(AppColors.success)
                    } else {
                        Text(day.date.formatted(.dateTime.day()))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(day.expected == 0 ? 0.45 : 0.9))
                    }
                }
                .frame(width: 32, height: 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                        }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func accessibilityLabel(for day: DaySummary) -> String {
        let name = day.date.relativeDayName
        guard day.expected > 0 else { return "\(name), nothing due" }
        return "\(name), \(day.done) of \(day.expected) done"
    }
}
