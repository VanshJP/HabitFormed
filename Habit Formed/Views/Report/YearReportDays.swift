import SwiftUI

/// The year card's days, drawn as `YearLayout` says (a row per month with a
/// square per day, or twelve small month calendars), with the legend under
/// them. Painted fills only, so `ImageRenderer` draws it.
struct YearReportDays: View {
    let report: YearReport
    let layout: YearLayout
    let palette: ReportPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch layout {
            case .pixels:
                YearPixels(report: report, palette: palette)
            case .months:
                YearMonths(report: report, palette: palette)
            }
            YearLegend(palette: palette)
        }
    }
}

// MARK: - Square

/// One day: the accent, deeper the more of the day got done and whole on a
/// perfect day; a quiet well on a day that asked nothing; an outline while
/// it is still ahead.
struct YearDaySquare: View {
    /// Nil while the day is still ahead.
    let day: DaySummary?
    let size: CGFloat
    let palette: ReportPalette

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        Group {
            if let day {
                shape.fill(day.expected == 0 ? palette.well : Self.fill(done: day.fraction, palette: palette))
            } else {
                shape.strokeBorder(palette.rule, lineWidth: 1)
            }
        }
        .frame(width: size, height: size)
    }

    /// A day that asked something, by the share done: empty at nothing, the
    /// accent fading in from a fifth, and all of it once perfect.
    static func fill(done fraction: Double, palette: ReportPalette) -> Color {
        if fraction >= 1 { return palette.accent }
        if fraction <= 0 { return palette.rule }
        return palette.accent.opacity(0.2 + 0.6 * fraction)
    }
}

// MARK: - Pixels

/// A row per month and a square per day, the month's initial at the leading
/// edge; the days a month does not have are left out.
private struct YearPixels: View {
    let report: YearReport
    let palette: ReportPalette

    private static let label: CGFloat = 12
    private static let labelGap: CGFloat = 6
    private static let gap: CGFloat = 2
    private static let cell = (YearReportCardView.contentWidth - label - labelGap - gap * 30) / 31

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(report.months) { month in
                HStack(spacing: Self.labelGap) {
                    Text(month.initial)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.secondary)
                        .frame(width: Self.label, alignment: .leading)
                    HStack(spacing: Self.gap) {
                        ForEach(0..<31, id: \.self) { index in
                            if index < month.length {
                                YearDaySquare(day: report.day(index, of: month), size: Self.cell, palette: palette)
                            }
                        }
                    }
                }
                .frame(height: Self.cell)
            }
        }
    }
}

// MARK: - Months

/// Twelve small month calendars, four to a row, each week starting on the
/// calendar's first weekday.
private struct YearMonths: View {
    let report: YearReport
    let palette: ReportPalette

    private static let perRow = 4
    private static let spacing: CGFloat = 14
    private static let gap: CGFloat = 2
    private static let width = (YearReportCardView.contentWidth - spacing * CGFloat(perRow - 1)) / CGFloat(perRow)
    private static let cell = (width - gap * 6) / 7

    var body: some View {
        let months = report.months
        let rows = stride(from: 0, to: months.count, by: Self.perRow).map { start in
            Array(months[start..<min(start + Self.perRow, months.count)])
        }
        VStack(alignment: .leading, spacing: 12) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: Self.spacing) {
                    ForEach(rows[index]) { month in
                        monthGrid(month)
                    }
                }
            }
        }
    }

    private func monthGrid(_ month: YearReport.Month) -> some View {
        let weeks = (month.leadingBlanks + month.length + 6) / 7
        return VStack(alignment: .leading, spacing: 4) {
            Text(month.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
            VStack(alignment: .leading, spacing: Self.gap) {
                ForEach(0..<weeks, id: \.self) { week in
                    HStack(spacing: Self.gap) {
                        ForEach(0..<7, id: \.self) { column in
                            let index = week * 7 + column - month.leadingBlanks
                            if index >= 0 && index < month.length {
                                YearDaySquare(day: report.day(index, of: month), size: Self.cell, palette: palette)
                            } else {
                                Color.clear
                                    .frame(width: Self.cell, height: Self.cell)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: Self.width, alignment: .leading)
    }
}

// MARK: - Legend

/// "Less" to "More" along the accent, then a perfect day's square.
private struct YearLegend: View {
    let palette: ReportPalette

    private let size: CGFloat = 10

    var body: some View {
        let ramp = [0, 0.25, 0.5, 0.75].map { YearDaySquare.fill(done: $0, palette: palette) }
        HStack(spacing: 4) {
            Text("Less")
                .padding(.trailing, 2)
            ForEach(ramp.indices, id: \.self) { index in
                swatch(ramp[index])
            }
            Text("More")
                .padding(.leading, 2)
            Spacer(minLength: 12)
            swatch(palette.accent)
            Text("Perfect day")
                .padding(.leading, 2)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(palette.secondary)
        .lineLimit(1)
    }

    private func swatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
    }
}
