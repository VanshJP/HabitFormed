import SwiftUI

/// The report's Minimal layout: the day's count set large, a hairline, and
/// the habits in two columns, a dot each, filled in the habit's colour once
/// done. Typographic and quiet, so no glyphs, runs or details. Painted fills
/// only, so `ImageRenderer` draws it.
struct ReportMinimal: View {
    let report: DailyReport
    let options: ReportOptions
    let palette: ReportPalette

    /// Names listed before "+N more": six rows of two.
    static let maxNames = 12

    var body: some View {
        let shown = Array(report.items.prefix(Self.maxNames))
        // The first column takes the odd one, so the two stay level.
        let split = (shown.count + 1) / 2

        VStack(alignment: .leading, spacing: 16) {
            // Figures have no descenders, so the label tucks up under them.
            VStack(alignment: .leading, spacing: -10) {
                Text(report.countText)
                    .font(.system(size: 96, weight: .bold, design: options.font.numerals).monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(report.expected == 0 ? "Rest day" : "Habits done")
                    .eyebrowStyle(palette.secondary)
            }

            Rectangle()
                .fill(palette.rule)
                .frame(height: 0.5)

            if shown.isEmpty {
                Text("No habits on this card")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    column(Array(shown[..<split]))
                    column(Array(shown[split...]))
                }
            }

            if report.items.count > shown.count {
                Text("+\(report.items.count - shown.count) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func column(_ items: [DailyReport.Item]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items) { name($0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A dot and the name: filled in the habit's colour and inked once done,
    /// hollow and softer while not.
    private func name(_ item: DailyReport.Item) -> some View {
        HStack(spacing: 8) {
            Group {
                if item.isDone {
                    Circle().fill(palette.habitTint(item.colorHex))
                } else {
                    Circle().strokeBorder(palette.faint, lineWidth: 1.2)
                }
            }
            .frame(width: 7, height: 7)

            Text(item.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(item.isDone ? palette.ink : palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ReportMinimal(report: .sample, options: ReportOptions(), palette: ReportPalette(options: ReportOptions()))
        .frame(width: 342)
        .padding()
        .background(Color.black)
}
#endif
