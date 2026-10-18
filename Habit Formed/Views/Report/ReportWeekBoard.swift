import SwiftUI

/// The report's Week layout: the last seven days as a board, a row per
/// habit and a square per day, filled with the habit's color when logged.
/// Today's column carries the bold letter, and an open today is a dashed
/// square. Painted fills only, like the rest of the card, so
/// `ImageRenderer` draws it.
struct ReportWeekBoard: View {
    let report: DailyReport
    let palette: ReportPalette
    let showStreaks: Bool

    private let square: CGFloat = 14
    private let gap: CGFloat = 3
    private let glyphColumn: CGFloat = 20
    /// Wide enough for a flame and three digits.
    private let streakColumn: CGFloat = 36

    var body: some View {
        let shown = Array(report.items.prefix(ReportCardView.maxItems))
        let days = (0..<7).map { report.date.adding(days: $0 - 6) }

        VStack(alignment: .leading, spacing: 10) {
            line {
                Color.clear.frame(height: 1)
            } days: {
                ForEach(days.indices, id: \.self) { index in
                    Text(days[index].formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(index == 6 ? .heavy : .semibold))
                        .foregroundStyle(index == 6 ? palette.ink : palette.faint)
                        .frame(width: square)
                }
            } streak: {
                Color.clear.frame(height: 1)
            }

            if shown.isEmpty {
                Text("No habits on this card")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
            }
            ForEach(shown) { item in
                let tint = palette.habitTint(item.colorHex)
                line {
                    HStack(spacing: 6) {
                        Image(systemName: item.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                            .frame(width: glyphColumn)
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.ink.opacity(item.isDone ? 1 : 0.7))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                } days: {
                    ForEach(0..<7, id: \.self) { cell(item, day: $0) }
                } streak: {
                    // Something even with no run, so the column keeps its room.
                    if item.streak > 0 {
                        ReportStreakCount(streak: item.streak, color: palette.secondary)
                    } else {
                        Color.clear.frame(height: 1)
                    }
                }
            }
            if report.items.count > shown.count {
                Text("+\(report.items.count - shown.count) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondary)
                    .padding(.leading, glyphColumn + 6)
            }
        }
        .padding(14)
        .background(palette.well, in: .rect(cornerRadius: AppLayout.tileRadius, style: .continuous))
    }

    /// One row of the board: the name column takes what is left, so every
    /// row's squares and streak line up under the day letters.
    private func line<Name: View, Days: View, Streak: View>(
        @ViewBuilder name: () -> Name,
        @ViewBuilder days: () -> Days,
        @ViewBuilder streak: () -> Streak
    ) -> some View {
        HStack(spacing: 8) {
            name()
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: gap) { days() }
            if showStreaks {
                streak()
                    .frame(width: streakColumn, alignment: .trailing)
            }
        }
    }

    private func cell(_ item: DailyReport.Item, day: Int) -> some View {
        let logged = item.week.indices.contains(day) && item.week[day]
        let openToday = day == 6 && item.status == .open
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        return shape
            .fill(logged ? Color(hex: item.colorHex) : openToday ? .clear : palette.rule)
            .overlay {
                if openToday {
                    shape.strokeBorder(palette.faint, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                }
            }
            .frame(width: square, height: square)
    }
}
