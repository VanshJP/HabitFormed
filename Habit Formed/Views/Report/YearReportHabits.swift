import SwiftUI

/// The year card's habits as a table, best rate first: each habit's rate as
/// a bar and a percentage, its logs, and its best run while the card shows
/// streaks. Painted fills only, so `ImageRenderer` draws it.
struct YearReportHabits: View {
    let rows: [YearReport.Row]
    let palette: ReportPalette
    let showStreaks: Bool
    /// Rows listed before "+N more".
    let maxRows: Int

    private let glyphWidth: CGFloat = 18
    private let barWidth: CGFloat = 44
    private let rateWidth: CGFloat = 38
    private let logsWidth: CGFloat = 36
    private let runWidth: CGFloat = 64

    var body: some View {
        let shown = Array(rows.prefix(maxRows))
        let hidden = rows.count - shown.count

        VStack(alignment: .leading, spacing: 7) {
            if shown.isEmpty {
                Text("No habits on this card")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
            } else {
                columns {
                    Text("Habit")
                } rate: {
                    Text("Rate")
                } logs: {
                    Text("Logs")
                } run: {
                    Text("Best run")
                }
                .eyebrowStyle(palette.secondary)
                .lineLimit(1)

                ForEach(shown) { row in
                    line(row)
                }

                if hidden > 0 {
                    Text("+\(hidden) more")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondary)
                        .padding(.leading, glyphWidth + 8)
                }
            }
        }
    }

    /// One line of the table: the name takes what is left, so every number
    /// lines up under its heading.
    private func columns<Name: View, Rate: View, Logs: View, Run: View>(
        @ViewBuilder name: () -> Name,
        @ViewBuilder rate: () -> Rate,
        @ViewBuilder logs: () -> Logs,
        @ViewBuilder run: () -> Run
    ) -> some View {
        HStack(spacing: 10) {
            name()
                .frame(maxWidth: .infinity, alignment: .leading)
            rate()
                .frame(width: barWidth + 6 + rateWidth, alignment: .trailing)
            logs()
                .frame(width: logsWidth, alignment: .trailing)
            if showStreaks {
                run()
                    .frame(width: runWidth, alignment: .trailing)
            }
        }
    }

    private func line(_ row: YearReport.Row) -> some View {
        let tint = palette.habitTint(row.colorHex)

        return columns {
            HStack(spacing: 8) {
                Image(systemName: row.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: glyphWidth)
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        } rate: {
            HStack(spacing: 6) {
                bar(row.rate, tint: tint)
                Text("\((row.rate * 100).safeRounded)%")
                    .font(.footnote.weight(.bold).monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .frame(width: rateWidth, alignment: .trailing)
            }
        } logs: {
            Text(row.logs.formatted())
                .font(.footnote.monospacedDigit())
                .foregroundStyle(palette.secondary)
        } run: {
            Text("\(row.bestRun) \(row.runUnit)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    /// The rate as a thin bar in the habit's colour; any rate above nothing
    /// shows at least a dot.
    private func bar(_ rate: Double, tint: Color) -> some View {
        let share = CGFloat(min(max(rate, 0), 1))
        return Capsule()
            .fill(palette.rule)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(tint)
                    .frame(width: share > 0 ? max(barWidth * share, 4) : 0)
            }
            .frame(width: barWidth, height: 4)
    }
}
