import SwiftUI

// The report card's other two layouts (`ReportLayout`). Painted fills only,
// like the rest of the card, so `ImageRenderer` draws them.

// MARK: - Grid

/// A square per habit, three across, filled with its colour once done: the
/// card looks like Today does. Rows are built by hand, not lazily, because
/// `ImageRenderer` draws one pass.
struct ReportHabitGrid: View {
    let items: [DailyReport.Item]
    let palette: ReportPalette
    let showStreaks: Bool

    private let columns = 3
    private let spacing: CGFloat = 8

    var body: some View {
        let shown = Array(items.prefix(ReportCardView.maxItems))
        let rows = stride(from: 0, to: shown.count, by: columns).map { Array(shown[$0..<min($0 + columns, shown.count)]) }

        VStack(spacing: spacing) {
            if shown.isEmpty {
                Text("No habits on this card.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: spacing) {
                    ForEach(rows[index]) { tile($0) }
                    // Keeps a short last row's squares the size of the rest.
                    ForEach(0..<(columns - rows[index].count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            if items.count > shown.count {
                Text("+\(items.count - shown.count) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func tile(_ item: DailyReport.Item) -> some View {
        let tint = palette.habitTint(item.colorHex)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: item.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(item.isDone ? .white : tint)
                Spacer(minLength: 4)
                if showStreaks, item.streak > 0 {
                    Text("\(item.streak)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(item.isDone ? .white.opacity(0.85) : palette.secondary)
                }
            }
            Spacer(minLength: 6)
            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.isDone ? .white : palette.ink.opacity(0.7))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .background(
            item.isDone ? Color(hex: item.colorHex) : palette.well,
            in: .rect(cornerRadius: AppLayout.tileRadius, style: .continuous)
        )
    }
}

// MARK: - Focus

/// The day at a glance: one big ring with the count, the verdict under it,
/// and a strip of glyphs, filled once done.
struct ReportFocus: View {
    let report: DailyReport
    let palette: ReportPalette
    let showStreaks: Bool
    var numerals: Font.Design = .rounded

    var body: some View {
        VStack(spacing: 16) {
            ProgressRing(
                fraction: report.fraction,
                lineWidth: 14,
                color: report.isPerfect ? AppColors.success : palette.accent
            ) {
                VStack(spacing: 2) {
                    Text("\(report.done)/\(report.expected)")
                        .font(.system(size: 44, weight: .bold, design: numerals).monospacedDigit())
                        .foregroundStyle(palette.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(report.percentText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.secondary)
                }
                .padding(.horizontal, 20)
            }
            .frame(width: 170, height: 170)

            VStack(spacing: 4) {
                Text(report.verdict)
                    .font(.title2.bold())
                    .foregroundStyle(palette.ink)
                if showStreaks, report.perfectStreak > 0 {
                    Text(report.perfectStreak == 1 ? "1 perfect day" : "\(report.perfectStreak) perfect days in a row")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.ink.opacity(0.85))
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(report.items.prefix(ReportCardView.maxItems * 2)) { glyph($0) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func glyph(_ item: DailyReport.Item) -> some View {
        let tint = palette.habitTint(item.colorHex)
        return Image(systemName: item.symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(item.isDone ? .white : tint.opacity(0.8))
            .frame(width: 38, height: 38)
            .background {
                if item.isDone {
                    Circle().fill(Color(hex: item.colorHex))
                } else {
                    Circle().strokeBorder(palette.rule, lineWidth: 1.5)
                }
            }
            .accessibilityLabel("\(item.title), \(item.isDone ? "done" : "not done")")
    }
}
