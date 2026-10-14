import SwiftUI

/// One day in History, closed: its name, the glyphs of what got logged, and
/// how much of the day that was (green when perfect). History opens it in
/// place to list the logs and offer the day's report.
struct DayRow: View {
    let date: Date
    let completions: [HabitCompletion]
    let summary: DaySummary
    let isOpen: Bool

    private let glyphLimit = 8

    var body: some View {
        HStack(spacing: RowLayout.spacing) {
            VStack(alignment: .leading, spacing: 6) {
                Text(date.relativeDayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 7) {
                    ForEach(completions.prefix(glyphLimit)) { completion in
                        Image(systemName: completion.habit?.symbol ?? "circle.fill")
                            .font(.caption)
                            .foregroundStyle((completion.habit?.color ?? .gray).glyphTone)
                    }
                    if completions.count > glyphLimit {
                        Text("+\(completions.count - glyphLimit)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityHidden(true)
            }

            Spacer(minLength: 8)

            Text(count)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(summary.isPerfect ? AnyShapeStyle(AppColors.success) : AnyShapeStyle(.secondary))
            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isOpen ? 180 : 0))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, RowLayout.horizontalPadding)
        .padding(.vertical, RowLayout.verticalPadding)
        .frame(maxWidth: .infinity, minHeight: AppLayout.minHitTarget, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint(isOpen ? "Hides the logs." : "Shows the logs.")
    }

    /// "2 of 3" for a day that expected habits; a bare log count otherwise.
    private var count: String {
        summary.expected > 0 ? "\(summary.done) of \(summary.expected)" : "\(completions.count)"
    }
}
