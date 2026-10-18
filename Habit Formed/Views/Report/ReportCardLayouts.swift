import SwiftUI

// The report card's Grid and Focus layouts (`ReportLayout`), and the pieces
// several layouts share. Painted fills only, like the rest of the card, so
// `ImageRenderer` draws them.

// MARK: - Shared

extension ReportPalette {
    /// A done habit's solid fill under white ink: its colour a step deeper,
    /// so the lighter swatches still hold white text.
    func doneFill(_ hex: String) -> Color {
        Color(hex: hex).mix(with: .black, by: 0.15)
    }
}

/// A habit's run as a small flame and its number, so a bare "12" never has
/// to explain itself.
struct ReportStreakCount: View {
    let streak: Int
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.caption2.weight(.semibold))
            Text("\(streak)")
                .font(.caption.weight(.bold).monospacedDigit())
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .fixedSize()
    }
}

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
                Text("No habits on this card")
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
                // Every square in a row as tall as its longest name.
                .fixedSize(horizontal: false, vertical: true)
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
                    ReportStreakCount(streak: item.streak, color: item.isDone ? .white.opacity(0.85) : palette.secondary)
                }
            }
            Spacer(minLength: 6)
            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.isDone ? .white : palette.ink.opacity(0.7))
                .lineLimit(3)
                .minimumScaleFactor(0.92)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 84, maxHeight: .infinity, alignment: .topLeading)
        .background(
            item.isDone ? palette.doneFill(item.colorHex) : palette.well,
            in: .rect(cornerRadius: AppLayout.tileRadius, style: .continuous)
        )
    }
}

// MARK: - Focus

/// The day at a glance: one big ring with the count, and a centred strip of
/// glyphs under it, filled once done.
struct ReportFocus: View {
    let report: DailyReport
    let palette: ReportPalette
    var numerals: Font.Design = .rounded

    var body: some View {
        let shown = Array(report.items.prefix(ReportCardView.maxItems * 2))

        VStack(spacing: 16) {
            ReportDayRing(report: report, palette: palette, diameter: 170, lineWidth: 14) {
                Text(report.countText)
                    .font(.system(size: 44, weight: .bold, design: numerals).monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 20)
            }

            if !shown.isEmpty {
                FlowLayout(spacing: 8, centred: true) {
                    ForEach(shown) { glyph($0) }
                }
            }

            if report.items.count > shown.count {
                Text("+\(report.items.count - shown.count) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondary)
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
                    Circle().fill(palette.doneFill(item.colorHex))
                } else {
                    Circle().strokeBorder(palette.rule, lineWidth: 1.5)
                }
            }
            .accessibilityLabel("\(item.title), \(item.isDone ? "done" : "not done")")
    }
}
