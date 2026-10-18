import SwiftUI

/// The report's Garden layout: a plant per habit, up to five to a bed. A
/// bloom in its colour says done today, and a bud says still open, a Health
/// habit's bud filled as far as its reading has come. With streaks on, a
/// leaf per step of its run (a day, or a week for a weekly habit) grows the
/// stem, and the run is named under the plant. Each bed is as tall as its
/// tallest plant. Painted fills only, so `ImageRenderer` draws it.
struct ReportGarden: View {
    let report: DailyReport
    let palette: ReportPalette
    let showStreaks: Bool

    /// Plants a bed holds before the next one starts, so every name wraps on
    /// whole words.
    static let perBed = 5
    /// Two beds at most; past them, "+N more".
    static let maxPlants = 10
    /// Leaves past this many would grow the stem too tall; the run under the
    /// plant still says the whole count.
    private let maxLeaves = 4
    private let leafStep: CGFloat = 30
    private let bloom: CGFloat = 32

    private var stemColor: Color { palette.dataTint(AppColors.leaf).opacity(palette.isLight ? 0.9 : 0.75) }
    private var leafColor: Color { palette.dataTint(AppColors.leaf) }

    var body: some View {
        let shown = Array(report.items.prefix(Self.maxPlants))
        let beds = Self.beds(of: shown)

        VStack(alignment: .leading, spacing: 14) {
            if shown.isEmpty {
                Text("No habits on this card")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
            }
            ForEach(beds.indices, id: \.self) { index in
                bed(beds[index])
            }
            if report.items.count > shown.count {
                Text("+\(report.items.count - shown.count) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondary)
            }
        }
    }

    /// The plants shared evenly over as few beds as hold them: seven is four
    /// and three.
    private static func beds(of items: [DailyReport.Item]) -> [[DailyReport.Item]] {
        guard !items.isEmpty else { return [] }
        let count = (items.count + perBed - 1) / perBed
        let size = (items.count + count - 1) / count
        return stride(from: 0, to: items.count, by: size).map { Array(items[$0..<min($0 + size, items.count)]) }
    }

    // MARK: - A bed

    private func bed(_ plants: [DailyReport.Item]) -> some View {
        let height = plants.map { reach(of: $0) }.max() ?? 0

        return VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(plants) { plant($0).frame(maxWidth: .infinity) }
            }
            .frame(height: height + 4, alignment: .bottom)
            Rectangle().fill(palette.faint).frame(height: 1.5)
            Rectangle().fill(palette.well).frame(height: 8)
            HStack(alignment: .top, spacing: 0) {
                ForEach(plants) { tag($0).frame(maxWidth: .infinity) }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - A plant

    private func leafCount(of item: DailyReport.Item) -> Int {
        showStreaks ? min(item.streak, maxLeaves) : 0
    }

    private func stemHeight(of item: DailyReport.Item) -> CGFloat {
        let count = leafCount(of: item)
        return count == 0 && !item.isDone ? 16 : 30 + CGFloat(count) * leafStep
    }

    private func headSize(of item: DailyReport.Item) -> CGSize {
        if item.isDone { return CGSize(width: bloom, height: bloom) }
        return leafCount(of: item) == 0 ? CGSize(width: 9, height: 14) : CGSize(width: 13, height: 20)
    }

    /// How far a plant stands above the ground, its head included.
    private func reach(of item: DailyReport.Item) -> CGFloat {
        stemHeight(of: item) - 4 + headSize(of: item).height
    }

    private func plant(_ item: DailyReport.Item) -> some View {
        let count = leafCount(of: item)
        let height = stemHeight(of: item)
        return ZStack(alignment: .bottom) {
            Capsule()
                .fill(stemColor)
                .frame(width: 2.5, height: height)
            ForEach(0..<count, id: \.self) { index in
                let left = index.isMultiple(of: 2)
                Ellipse()
                    .fill(leafColor)
                    .frame(width: 17, height: 8)
                    .rotationEffect(.degrees(left ? -35 : 35))
                    .offset(x: left ? -8 : 8, y: -(16 + CGFloat(index) * leafStep))
            }
            head(item)
                .offset(y: -height + 4)
        }
    }

    /// A bloom of six petals round a pale heart once done; a closed bud
    /// while open, filled from the bottom as far as a reading has come.
    @ViewBuilder
    private func head(_ item: DailyReport.Item) -> some View {
        let color = Color(hex: item.colorHex)
        if item.isDone {
            ZStack {
                ForEach(0..<6, id: \.self) { index in
                    let angle = Double(index) / 6 * 2 * .pi
                    Circle()
                        .fill(color)
                        .frame(width: 15, height: 15)
                        .offset(x: 8.5 * sin(angle), y: -8.5 * cos(angle))
                }
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 9, height: 9)
            }
            .frame(width: bloom, height: bloom)
        } else {
            let tint = palette.habitTint(item.colorHex)
            let size = headSize(of: item)
            Ellipse()
                .fill(tint.opacity(0.18))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(tint)
                        .frame(height: size.height * CGFloat(item.progress ?? 0))
                }
                .clipShape(Ellipse())
                .overlay { Ellipse().strokeBorder(tint, lineWidth: 1.5) }
                .frame(width: size.width, height: size.height)
        }
    }

    // MARK: - Tag

    private func tag(_ item: DailyReport.Item) -> some View {
        VStack(spacing: 2) {
            Text(item.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.ink.opacity(item.isDone ? 1 : 0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .allowsTightening(true)
            if let line = runText(item) {
                Text(line)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 3)
    }

    /// "45%" for a Health habit still growing; with streaks on, "3 days" or
    /// "2 wks". Nothing for a run not yet started.
    private func runText(_ item: DailyReport.Item) -> String? {
        if !item.isDone, let progress = item.progress { return "\((progress * 100).safeRounded)%" }
        guard showStreaks, item.streak > 0 else { return nil }
        return "\(item.streak) \(item.streakUnit)"
    }
}
