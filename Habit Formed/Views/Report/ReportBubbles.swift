import SwiftUI

/// The report's Bubbles layout: a circle per habit in a honeycomb, rows of
/// three and two nesting into each other, filled with the habit's color
/// once done and ringed in it while open. Painted fills only, like the rest
/// of the card, so `ImageRenderer` draws it.
struct ReportBubbles: View {
    let items: [DailyReport.Item]
    let palette: ReportPalette
    let showStreaks: Bool

    private let size: CGFloat = 104
    private let gap: CGFloat = 8

    var body: some View {
        let shown = Array(items.prefix(ReportCardView.maxItems))
        // Centres one bubble and a gap apart sit 0.866 of that apart down a
        // honeycomb, so rows overlap by the difference.
        let rowSpacing = (size + gap) * 0.866 - size

        VStack(spacing: rowSpacing) {
            if shown.isEmpty {
                Text("No habits on this card.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(Self.rows(of: shown), id: \.first?.id) { row in
                HStack(spacing: gap) {
                    ForEach(row) { bubble($0) }
                }
            }
            if items.count > shown.count {
                Text("+\(items.count - shown.count) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondary)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Three, then two, then three, so each row sits in the gaps of the last.
    private static func rows(of items: [DailyReport.Item]) -> [[DailyReport.Item]] {
        var rows: [[DailyReport.Item]] = []
        var start = 0
        while start < items.count {
            let count = rows.count.isMultiple(of: 2) ? 3 : 2
            rows.append(Array(items[start..<min(start + count, items.count)]))
            start += count
        }
        return rows
    }

    private func bubble(_ item: DailyReport.Item) -> some View {
        let tint = palette.habitTint(item.colorHex)
        return VStack(spacing: 3) {
            Image(systemName: item.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(item.isDone ? .white : tint)
            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.isDone ? .white : palette.ink.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if showStreaks, item.streak > 0 {
                Text("\(item.streak) \(item.streakUnit)")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(item.isDone ? .white.opacity(0.75) : palette.secondary)
            }
        }
        .padding(14)
        .frame(width: size, height: size)
        .background {
            ZStack {
                if item.isDone {
                    Circle().fill(Color(hex: item.colorHex))
                } else {
                    Circle().fill(palette.well)
                    Circle().strokeBorder(tint.opacity(0.5), lineWidth: 1.5)
                }
            }
        }
    }
}
