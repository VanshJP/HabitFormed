import SwiftUI

/// The shareable card for the year so far: who and which days, three
/// numbers, every day since January 1, each habit's rate, and the month and
/// weekday that stood out. Same rules as the daily card: a fixed width,
/// Dynamic Type pinned and painted fills only, so `ImageRenderer` draws it
/// and it looks the same wherever it is sent.
struct YearReportCardView: View {
    let report: YearReport
    /// The daily card's look: theme, accent and type, and the year's own
    /// layout (`yearLayout`).
    let options: ReportOptions

    /// The width inside the card's inset, which the day grids divide.
    static let contentWidth: CGFloat = ReportCardView.width - 48
    /// Habits listed before "+N more", so the card stays a sensible height.
    static let maxRows = 5

    private var palette: ReportPalette { ReportPalette(options: options) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ReportCardHeader(
                title: report.name.isEmpty ? "Year in review" : report.name,
                subtitle: "\(report.rangeText), \(String(report.year))",
                palette: palette
            )
            .reportRegion(.header)

            stats

            YearReportDays(report: report, layout: options.yearLayout, palette: palette)
                .reportRegion(.habits)

            YearReportHabits(rows: report.rows, palette: palette, showStreaks: options.showStreaks, maxRows: Self.maxRows)
                .reportRegion(.habits)

            if report.bestMonth != nil || report.bestWeekday != nil {
                highlights
            }

            if !options.trimmedNote.isEmpty {
                ReportNote(text: options.trimmedNote, palette: palette)
                    .reportRegion(.note)
            }
        }
        .reportCardFrame(options: options, palette: palette)
        .reportInk(palette)
    }

    // MARK: - Numbers

    private var stats: some View {
        HStack(alignment: .top, spacing: 12) {
            stat("Perfect days", value: "\(report.perfectDays)")
            stat("Logs", value: report.logged.formatted())
            stat("Best run", value: "\(report.bestRun)", unit: report.bestRun == 1 ? "day" : "days")
        }
    }

    private func stat(_ label: String, value: String, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .eyebrowStyle(palette.secondary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: options.font.numerals).monospacedDigit())
                    .foregroundStyle(palette.ink)
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.secondary)
                }
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Highlights

    private var highlights: some View {
        HStack(alignment: .top, spacing: 12) {
            if let month = report.bestMonth {
                highlight(month)
            }
            if let weekday = report.bestWeekday {
                highlight(weekday)
            }
        }
    }

    private func highlight(_ item: YearReport.Highlight) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title)
                .eyebrowStyle(palette.secondary)
                .lineLimit(1)
            Text(item.value)
                .font(.system(size: 15, weight: .bold, design: options.font.numerals).monospacedDigit())
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#if DEBUG
extension YearReport {
    /// The year so far for previews: habits from mid-January, most days done.
    static var sample: YearReport {
        let calendar = Calendar.current
        let end = Date().startOfDay
        var date = calendar.dateInterval(of: .year, for: end)?.start ?? end
        var days: [DaySummary] = []
        var index = 0
        while date <= end {
            // A steady spread: mostly perfect, some partial, a few blank.
            let roll = (index * 37 + index / 7 * 11) % 100
            let expected = index < 12 ? 0 : 5
            let done = roll < 58 ? 5 : roll < 80 ? 4 : roll < 90 ? 3 : roll < 97 ? 1 : 0
            days.append(DaySummary(date: date, done: expected == 0 ? 0 : done, expected: expected))
            date = date.nextDayStart
            index += 1
        }

        func row(_ title: String, _ symbol: String, _ hex: String, _ logs: Int, _ rate: Double, _ run: Int, _ unit: String = "days") -> Row {
            Row(id: UUID(), title: title, symbol: symbol, colorHex: hex, logs: logs, rate: rate, bestRun: run, runUnit: unit)
        }
        return YearReport(
            name: "Vansh",
            year: calendar.component(.year, from: end),
            days: days,
            rows: [
                row("Read", "book.fill", "#5966A6", 268, 0.94, 41),
                row("10k steps", "figure.walk", "#2BA8A8", 251, 0.88, 23),
                row("Practice piano", "pianokeys", "#8C5C84", 232, 0.81, 17),
                row("Workout", "dumbbell.fill", "#BF7866", 118, 0.79, 9, "wks"),
                row("Meditate", "brain.head.profile", "#739F80", 203, 0.71, 12),
                row("Water the plants", "leaf.fill", "#BF9351", 61, 0.66, 14, "cycles"),
                row("Journal", "pencil.line", "#CC6B85", 140, 0.52, 6),
            ]
        )
    }
}

#Preview("Year") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(YearLayout.allCases) { layout in
                YearReportCardView(report: .sample, options: ReportOptions(yearLayout: layout, note: "Twelve weeks to go."))
            }
            YearReportCardView(report: .sample, options: ReportOptions(theme: .paper, yearLayout: .pixels, showStreaks: false))
        }
        .padding()
    }
    .background(Color.black)
}
#endif
