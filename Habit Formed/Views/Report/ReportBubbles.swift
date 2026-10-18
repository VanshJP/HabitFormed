import SwiftUI

/// The report's Bubbles layout: a circle per habit in a honeycomb, each row
/// nesting into the gaps of the next, filled with the habit's color once
/// done and ringed in it while open. Painted fills only, like the rest of
/// the card, so `ImageRenderer` draws it.
struct ReportBubbles: View {
    let items: [DailyReport.Item]
    let palette: ReportPalette
    let showStreaks: Bool

    /// One size for every count, so a name always has three lines to wrap
    /// in; a long list makes a taller card rather than smaller bubbles.
    private let size: CGFloat = 104
    private let gap: CGFloat = 8

    var body: some View {
        let shown = Array(items.prefix(ReportCardView.maxItems))
        let rows = Self.rows(of: shown)
        // Centres one bubble and a gap apart sit 0.866 of that apart down a
        // honeycomb, so rows overlap by the difference.
        let rowSpacing = (size + gap) * 0.866 - size

        VStack(spacing: rowSpacing) {
            if shown.isEmpty {
                Text("No habits on this card")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(rows, id: \.first?.id) { row in
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

    private static func rows(of items: [DailyReport.Item]) -> [[DailyReport.Item]] {
        var start = 0
        return rowPlan(for: items.count).map { length in
            defer { start += length }
            return Array(items[start..<start + length])
        }
    }

    /// Row lengths for a honeycomb of `count`. A row of one or three centres
    /// a bubble and a row of two centres a gap, so they take turns and every
    /// row sits in the gaps of the next; two rows alike would stack bubble on
    /// bubble. Fewest rows wins, then the most even shape (seven is 2, 3, 2),
    /// then the fuller top.
    static func rowPlan(for count: Int) -> [Int] {
        var best: [Int] = []
        func score(_ plan: [Int]) -> (Int, Int, Int) {
            let unevenness = zip(plan, plan.reversed()).reduce(0) { $0 + abs($1.0 - $1.1) }
            return (plan.count, unevenness, -(plan.first ?? 0))
        }
        func search(_ plan: [Int], left: Int) {
            if left == 0 {
                if best.isEmpty || score(plan) < score(best) { best = plan }
                return
            }
            if !best.isEmpty && plan.count >= best.count { return }
            let next: [Int] = plan.last.map { $0 == 2 ? [3, 1] : [2] } ?? [3, 2, 1]
            for length in next where length <= left {
                search(plan + [length], left: left - length)
            }
        }
        search([], left: count)
        return best
    }

    private func bubble(_ item: DailyReport.Item) -> some View {
        let tint = palette.habitTint(item.colorHex)
        return VStack(spacing: 2) {
            Image(systemName: item.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(item.isDone ? .white : tint)
            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.isDone ? .white : palette.ink.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.92)
            if showStreaks, item.streak > 0 {
                Text("\(item.streak) \(item.streakUnit)")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(item.isDone ? .white.opacity(0.75) : palette.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(width: size, height: size)
        .background {
            ZStack {
                if item.isDone {
                    Circle().fill(palette.doneFill(item.colorHex))
                } else {
                    Circle().fill(palette.well)
                    Circle().strokeBorder(tint.opacity(0.5), lineWidth: 1.5)
                }
            }
        }
    }
}
