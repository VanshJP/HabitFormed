import SwiftUI

/// The report's Punch card layout: a kraft loyalty card on a dark table, a
/// row per habit and a hole per day of the last week, punched clean through
/// (the table shows) on a day it was logged. The report's day is the last
/// column, banded in red, its open holes ringed in red; the run ends each row.
/// The Apple Health numbers follow as a typed carbon copy. It is the whole
/// image, whatever the card's background. Painted fills only, so
/// `ImageRenderer` draws it.
struct ReportPunchCard: View {
    let report: DailyReport
    let options: ReportOptions

    private let typed = Font.custom("Courier", size: 12)
    private let condensed = "Futura-CondensedExtraBold"
    private var cardSoft: Color { AppColors.kraftInk.opacity(0.72) }
    private var tableSoft: Color { AppColors.tableInk.opacity(0.7) }
    /// The card's inside (342 less its 14pt insets) split exactly: the name,
    /// seven holes and the run, 3pt between each.
    private let nameWidth: CGFloat = 134
    private let cell: CGFloat = 18
    private let runWidth: CGFloat = 30

    var body: some View {
        let shown = Array(report.items.prefix(ReportCardView.maxItems))
        let lines = report.health.lines(showing: options.metrics)
        let note = options.trimmedNote

        VStack(alignment: .leading, spacing: 18) {
            header
            card(shown)
            if !lines.isEmpty { carbonCopy(lines) }
            if !note.isEmpty {
                Text("Note: \(note)")
                    .font(typed)
                    .foregroundStyle(AppColors.tableInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 22)
        .frame(width: ReportCardView.width, alignment: .leading)
        .background(AppColors.table)
    }

    // MARK: - Parts

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(report.name.isEmpty ? "Daily report" : report.name)
                    .font(.custom(condensed, size: 26))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(report.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.custom("Courier", size: 13))
                    .foregroundStyle(tableSoft)
            }
            Spacer(minLength: 8)
            Text(report.countText)
                .font(.custom(condensed, size: 34))
        }
        .foregroundStyle(AppColors.tableInk)
    }

    private func card(_ shown: [DailyReport.Item]) -> some View {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: report.date) ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Habit card")
                    .font(.custom(condensed, size: 22))
                    .textCase(.uppercase)
                    .kerning(1.8)
                Spacer()
                Text("No. \(dayOfYear)")
                    .font(.custom("Courier", size: 11))
                    .foregroundStyle(cardSoft)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(AppColors.kraftRule).frame(height: 1.5) }

            dayLetters
            if shown.isEmpty {
                Text("No habits on this card")
                    .font(typed)
                    .foregroundStyle(cardSoft)
                    .padding(.vertical, 10)
            }
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                row(item, last: index == shown.count - 1)
            }
            if report.items.count > shown.count {
                Text("+\(report.items.count - shown.count) more")
                    .font(typed)
                    .foregroundStyle(cardSoft)
                    .padding(.vertical, 6)
            }
            HStack {
                Text("Punched = done")
                Spacer(minLength: 8)
                Text(report.isToday ? "Red ring = still open" : "Red ring = missed")
            }
            .font(.custom("Courier", size: 11))
            .foregroundStyle(cardSoft)
            .padding(.top, 10)
            .overlay(alignment: .top) { Rectangle().fill(AppColors.kraftRule).frame(height: 1.5) }
        }
        .foregroundStyle(AppColors.kraftInk)
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(AppColors.kraft, in: .rect(cornerRadius: 14, style: .continuous))
    }

    /// The week's weekday letters over the holes, the report's day bold.
    private var dayLetters: some View {
        let days = (0..<7).map { report.date.adding(days: $0 - 6) }
        return HStack(spacing: 3) {
            Color.clear.frame(width: nameWidth, height: 1)
            ForEach(days.indices, id: \.self) { index in
                Text(days[index].formatted(.dateTime.weekday(.narrow)))
                    .font(.custom(index == 6 ? "Courier-Bold" : "Courier", size: 11))
                    .foregroundStyle(index == 6 ? AppColors.kraftInk : cardSoft)
                    .frame(width: cell, height: 30)
                    .background(index == 6 ? AppColors.newsRed.opacity(0.1) : .clear)
            }
            Text(options.showStreaks ? "Run" : "")
                .font(.custom("Courier", size: 11))
                .textCase(.uppercase)
                .foregroundStyle(cardSoft)
                .frame(width: runWidth, alignment: .trailing)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(AppColors.kraftRule).frame(height: 1.5) }
    }

    private func row(_ item: DailyReport.Item, last: Bool) -> some View {
        HStack(spacing: 3) {
            Text(item.title)
                .font(typed)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .frame(width: nameWidth, alignment: .leading)
            ForEach(0..<7, id: \.self) { day in
                hole(item, day: day)
                    .frame(width: cell, height: 30)
                    .background(day == 6 ? AppColors.newsRed.opacity(0.1) : .clear)
            }
            Text(run(item))
                .font(.custom(condensed, size: 16))
                .foregroundStyle(item.streak > 0 ? AppColors.kraftInk : cardSoft)
                .frame(width: runWidth, alignment: .trailing)
        }
        .overlay(alignment: .bottom) {
            if !last {
                RowRule()
                    .stroke(AppColors.kraftRule.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [1, 2]))
                    .frame(height: 1)
            }
        }
    }

    /// Punched through to the table when logged; a printed ring when not; a
    /// red one for the report's day while it is open or was missed.
    @ViewBuilder
    private func hole(_ item: DailyReport.Item, day: Int) -> some View {
        let logged = item.week.indices.contains(day) && item.week[day]
        let reportDayOpen = day == 6 && (item.status == .open || item.status == .missed)
        if logged {
            Circle()
                .fill(AppColors.table)
                .overlay { Circle().strokeBorder(AppColors.kraftRule, lineWidth: 1) }
                .frame(width: 14, height: 14)
        } else {
            Circle()
                .strokeBorder(
                    reportDayOpen ? AppColors.newsRed : AppColors.kraftRule.opacity(0.8),
                    style: StrokeStyle(lineWidth: reportDayOpen ? 1.5 : 1, dash: [2, 2])
                )
                .frame(width: 14, height: 14)
        }
    }

    /// The run in days, or weeks for a weekly habit ("2w"); blank with
    /// streaks off.
    private func run(_ item: DailyReport.Item) -> String {
        guard options.showStreaks else { return "" }
        guard item.streak > 0 else { return "0" }
        return item.streakUnit.hasPrefix("wk") ? "\(item.streak)w" : "\(item.streak)"
    }

    /// The Health numbers typed in capitals, two to a line.
    private func carbonCopy(_ lines: [HealthLine]) -> some View {
        let rows = stride(from: 0, to: lines.count, by: 2).map { Array(lines[$0..<min($0 + 2, lines.count)]) }
        return VStack(alignment: .leading, spacing: 6) {
            Text("Carbon copy")
                .font(.custom("Courier", size: 11))
                .textCase(.uppercase)
                .kerning(1.6)
                .foregroundStyle(tableSoft)
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 12) {
                    ForEach(rows[index], id: \.self) { line in
                        Text("\(line.label) \(line.value)")
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if rows[index].count < 2 {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
        }
        .font(.custom("Courier", size: 12))
        .textCase(.uppercase)
        .foregroundStyle(AppColors.tableInk)
    }
}

/// A straight line across the middle of its frame, dotted by its stroke.
private struct RowRule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
