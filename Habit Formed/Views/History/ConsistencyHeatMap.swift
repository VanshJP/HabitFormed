import SwiftUI

/// Every habit at once: one cell per day for the last few weeks, filled by how
/// much of that day got done. Perfect days are solid.
struct ConsistencyHeatMap: View {
    /// Summaries keyed by the start of each day.
    let summaries: [Date: DaySummary]
    var weeks: Int = 12
    var cellSpacing: CGFloat = 4

    var body: some View {
        let grid = ActivityHeatMap.buildGrid(weeks: weeks)

        GeometryReader { proxy in
            let size = max(2, (proxy.size.width - cellSpacing * CGFloat(weeks - 1)) / CGFloat(weeks))
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(0..<grid.count, id: \.self) { col in
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { row in
                            cell(grid[col][row], size: size)
                        }
                    }
                }
            }
        }
        .aspectRatio(CGFloat(weeks) / 7.0, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private func cell(_ date: Date?, size: CGFloat) -> some View {
        if let date {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color(for: summaries[date]))
                .overlay {
                    if date.isToday {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                    }
                }
                .frame(width: size, height: size)
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }

    private func color(for summary: DaySummary?) -> Color {
        guard let summary, summary.expected > 0 else { return Color.white.opacity(0.05) }
        if summary.isPerfect { return AppColors.success }
        if summary.done == 0 { return Color.white.opacity(0.09) }
        return AppColors.success.opacity(0.22 + 0.5 * summary.fraction)
    }

    private var accessibilitySummary: String {
        let perfect = summaries.values.filter(\.isPerfect).count
        return "\(perfect) perfect days in the last \(weeks) weeks"
    }
}
