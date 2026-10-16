import SwiftUI

/// The report's Garden layout: a plant per habit on one strip of ground. A
/// leaf per step of its run (a day, or a week for a weekly habit) grows the
/// stem, a bloom in its colour says done today, and a bud says still open,
/// a Health habit's bud filled as far as its reading has come. Name and run
/// under each. Painted fills only, so `ImageRenderer` draws it.
struct ReportGarden: View {
    let report: DailyReport
    let palette: ReportPalette

    /// Past this many, plants grow too narrow to name.
    static let maxPlants = 8
    /// Leaves past this many would grow the stem off the card; the run under
    /// the plant still says the whole count.
    private let maxLeaves = 4
    /// Tall enough for four leaves and a bloom.
    private let bed: CGFloat = 214

    private var stem: Color { palette.dataTint(AppColors.leaf).opacity(palette.isLight ? 0.9 : 0.75) }
    private var leaf: Color { palette.dataTint(AppColors.leaf) }

    var body: some View {
        let shown = Array(report.items.prefix(Self.maxPlants))

        VStack(alignment: .leading, spacing: 10) {
            if shown.isEmpty {
                Text("No habits on this card.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
            } else {
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(shown) { plant($0).frame(maxWidth: .infinity) }
                    }
                    .frame(height: bed, alignment: .bottom)
                    Rectangle().fill(palette.faint).frame(height: 1.5)
                    Rectangle().fill(palette.well).frame(height: 8)
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(shown) { tag($0).frame(maxWidth: .infinity) }
                    }
                    .padding(.top, 8)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text("A bloom is done today, a bud is still open, and each leaf is one more in a row")
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if report.items.count > shown.count {
                    Spacer(minLength: 8)
                    Text("+\(report.items.count - shown.count) more")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondary)
                }
            }
        }
    }

    // MARK: - A plant

    private func plant(_ item: DailyReport.Item) -> some View {
        let leaves = min(item.streak, maxLeaves)
        let height: CGFloat = leaves == 0 && !item.isDone ? 16 : 34 + CGFloat(leaves) * 38
        return ZStack(alignment: .bottom) {
            Capsule()
                .fill(stem)
                .frame(width: 2.5, height: height)
            ForEach(0..<leaves, id: \.self) { index in
                let left = index.isMultiple(of: 2)
                Ellipse()
                    .fill(leaf)
                    .frame(width: 17, height: 8)
                    .rotationEffect(.degrees(left ? -35 : 35))
                    .offset(x: left ? -8 : 8, y: -(18 + CGFloat(index) * 38))
            }
            head(item)
                .offset(y: -height + 4)
        }
        .frame(height: bed, alignment: .bottom)
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
            .frame(width: 32, height: 32)
        } else {
            let tint = palette.habitTint(item.colorHex)
            let small = item.streak == 0
            Ellipse()
                .fill(tint.opacity(0.18))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(tint)
                        .frame(height: (small ? 14 : 20) * (item.progress ?? 0))
                }
                .clipShape(Ellipse())
                .overlay { Ellipse().strokeBorder(tint, lineWidth: 1.5) }
                .frame(width: small ? 9 : 13, height: small ? 14 : 20)
        }
    }

    private func tag(_ item: DailyReport.Item) -> some View {
        VStack(spacing: 2) {
            Text(item.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.ink.opacity(item.isDone ? 1 : 0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(run(item))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 2)
    }

    /// "3 days", "2 wks", "45%" for a Health habit still growing, "new".
    private func run(_ item: DailyReport.Item) -> String {
        if !item.isDone, let progress = item.progress { return "\((progress * 100).safeRounded)%" }
        return item.streak > 0 ? "\(item.streak) \(item.streakUnit)" : "new"
    }
}
