import SwiftUI

/// The report's Ledger layout: the day as a table, like a statement. A row
/// per habit with the day's mark, its run and its last seven days in
/// columns under eyebrow headings, and the day's total under a double rule.
/// Painted fills only, so `ImageRenderer` draws it.
struct ReportLedger: View {
    let report: DailyReport
    let options: ReportOptions
    let palette: ReportPalette

    private let spacing: CGFloat = 8
    private let glyphColumn: CGFloat = 20
    private let todayColumn: CGFloat = 44
    private let runColumn: CGFloat = 36
    private let square: CGFloat = 7
    private let squareGap: CGFloat = 2.5

    private var weekColumn: CGFloat { square * 7 + squareGap * 6 }
    /// Where a title starts, so headings and the total line up with it.
    private var titleInset: CGFloat { glyphColumn + spacing }

    /// "Today", or the weekday on a past day's card.
    private var dayHeading: String {
        report.isToday ? "Today" : report.date.formatted(.dateTime.weekday(.abbreviated))
    }

    var body: some View {
        let shown = Array(report.items.prefix(ReportCardView.maxItems))
        let hidden = report.items.count - shown.count

        VStack(alignment: .leading, spacing: 0) {
            headings
                .padding(.top, 12)
                .padding(.bottom, 8)
            Rectangle()
                .fill(palette.faint)
                .frame(height: 0.75)

            if shown.isEmpty {
                Text("No habits on this card")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
                    .padding(.vertical, 12)
                    .padding(.leading, titleInset)
            }
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                if index > 0 { hairline }
                row(item)
            }
            if hidden > 0 {
                hairline
                Text("+\(hidden) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondary)
                    .padding(.vertical, 8)
                    .padding(.leading, titleInset)
            }

            total
        }
        .padding(.horizontal, 14)
        .background(palette.well, in: .rect(cornerRadius: AppLayout.tileRadius, style: .continuous))
    }

    // MARK: - Columns

    /// One line of the table: the name takes what is left, so every row's
    /// marks, runs and squares line up under their headings.
    private func line<Name: View, Day: View, Run: View, Week: View>(
        @ViewBuilder name: () -> Name,
        @ViewBuilder day: () -> Day,
        @ViewBuilder run: () -> Run,
        @ViewBuilder week: () -> Week
    ) -> some View {
        HStack(alignment: .center, spacing: spacing) {
            name()
                .frame(maxWidth: .infinity, alignment: .leading)
            day()
                .frame(width: todayColumn)
            if options.showStreaks {
                run()
                    .frame(width: runColumn, alignment: .trailing)
            }
            if options.showWeek {
                week()
                    .frame(width: weekColumn, alignment: .trailing)
            }
        }
    }

    private var headings: some View {
        line {
            Text("Habit")
                .eyebrowStyle(palette.secondary)
                .padding(.leading, titleInset)
        } day: {
            Text(dayHeading)
                .eyebrowStyle(palette.secondary)
        } run: {
            Text("Run")
                .eyebrowStyle(palette.secondary)
        } week: {
            Text("7 days")
                .eyebrowStyle(palette.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var hairline: some View {
        Rectangle()
            .fill(palette.rule)
            .frame(height: 0.5)
    }

    // MARK: - Rows

    private func row(_ item: DailyReport.Item) -> some View {
        let tint = palette.habitTint(item.colorHex)

        return line {
            HStack(spacing: spacing) {
                Image(systemName: item.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: glyphColumn)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.ink.opacity(item.isDone ? 1 : 0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let detail = item.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(palette.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        } day: {
            dayMark(item.status, tint: tint)
        } run: {
            runFigure(item)
        } week: {
            weekSquares(item, tint: tint)
        }
        .padding(.vertical, 8)
    }

    /// Done is a check in the habit's colour, open a ring in it, missed a
    /// quiet ring (a card sent to friends is no place for red), and a day a
    /// weekly habit had off a dash.
    @ViewBuilder
    private func dayMark(_ status: DayStatus, tint: Color) -> some View {
        switch status {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
        case .open:
            Circle()
                .strokeBorder(tint, lineWidth: 1.5)
                .frame(width: 12, height: 12)
        case .missed:
            Circle()
                .strokeBorder(palette.faint, lineWidth: 1.5)
                .frame(width: 12, height: 12)
        case .flexible, .resting:
            dash
        }
    }

    /// The run with a short unit: "12d", "3w", "4×" for an interval habit's
    /// cycles. No run is a dash, as a statement prints a zero.
    @ViewBuilder
    private func runFigure(_ item: DailyReport.Item) -> some View {
        if item.streak > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(item.streak)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(palette.ink)
                Text(shortUnit(item.streakUnit))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            dash
        }
    }

    private func shortUnit(_ unit: String) -> String {
        if unit.hasPrefix("wk") { return "w" }
        if unit.hasPrefix("cycle") { return "×" }
        return "d"
    }

    /// The seven days ending on the card's day, oldest first.
    private func weekSquares(_ item: DailyReport.Item, tint: Color) -> some View {
        HStack(spacing: squareGap) {
            ForEach(0..<7, id: \.self) { day in
                let logged = item.week.indices.contains(day) && item.week[day]
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(logged ? tint : palette.rule)
                    .frame(width: square, height: square)
            }
        }
    }

    private var dash: some View {
        Capsule()
            .fill(palette.faint)
            .frame(width: 10, height: 2)
    }

    // MARK: - Total

    /// The day's count under the day's column, over a double rule.
    private var total: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 2) {
                Rectangle().fill(palette.faint).frame(height: 0.75)
                Rectangle().fill(palette.faint).frame(height: 0.75)
            }
            line {
                Text("Done")
                    .font(.subheadline.bold())
                    .foregroundStyle(palette.ink)
                    .padding(.leading, titleInset)
            } day: {
                Text(report.countText)
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } run: {
                Color.clear.frame(height: 1)
            } week: {
                Color.clear.frame(height: 1)
            }
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ReportLedger(report: .sample, options: ReportOptions(), palette: ReportPalette(options: ReportOptions()))
        .frame(width: 342)
        .padding()
        .background(Color.black)
}
#endif
