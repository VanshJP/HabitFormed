import SwiftUI

/// Under the Sundial: what the rim's bands are, a line per bead on the dial
/// (its number, the time, the habits logged then), and what the dial cannot
/// place, a line each: still open or missed, done with no time on the day,
/// and weekly habits off today.
struct ReportSundialKey: View {
    let report: DailyReport
    let options: ReportOptions
    let palette: ReportPalette
    let moments: [SundialMoment]
    let untimed: [DailyReport.Item]

    /// Beads listed before "And N more", so the card stays short in a chat.
    static let maxRows = 8

    var body: some View {
        let shown = Array(moments.prefix(Self.maxRows))
        let more = moments.dropFirst(Self.maxRows).reduce(0) { $0 + $1.items.count }
        let open: [String] = report.items
            .filter { $0.status == .open || $0.status == .missed }
            .map { openPhrase($0) }
        let off: [String] = report.items
            .filter { $0.status == .flexible }
            .map { offPhrase($0) }
        let openLabel = report.isToday ? "Still open" : "Missed"

        VStack(alignment: .leading, spacing: 8) {
            bands
            ForEach(shown) { row($0) }
            if more > 0 {
                line("And \(more) more")
            }
            if !open.isEmpty {
                line(openLabel + ": " + open.joined(separator: ", "))
            }
            if !untimed.isEmpty {
                line("Also done: " + untimed.map(\.title).joined(separator: ", "))
            }
            if !off.isEmpty {
                line("Off today: " + off.joined(separator: ", "))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Parts

    /// A key to the rim, only for the bands it shows.
    @ViewBuilder
    private var bands: some View {
        let sleep = options.shows(.sleep) && report.health.sleepSpan != nil
        let moved = options.shows(.exercise) && !report.health.workoutSpans.isEmpty
        if sleep || moved {
            HStack(spacing: 16) {
                if sleep { key("Asleep", tint: ReportSundial.sleepTint(palette)) }
                if moved { key("Workouts", tint: ReportSundial.workoutTint(palette)) }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
        }
    }

    private func key(_ text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(tint)
                .frame(width: 16, height: 4)
            Text(text)
                .font(.caption)
                .foregroundStyle(palette.secondary)
        }
    }

    private func row(_ moment: SundialMoment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            SundialBead(moment: moment, diameter: 18)
            Text(moment.time.formatted(date: .omitted, time: .shortened))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 66, alignment: .leading)
            Text(moment.items.map(\.title).joined(separator: ", "))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(palette.secondary)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Words

    /// "Steps (8.2k of 10k steps)" for a Health habit, "Read (4-day run at
    /// stake)" while streaks are on, or the name alone.
    private func openPhrase(_ item: DailyReport.Item) -> String {
        if item.progress != nil, let detail = item.detail { return "\(item.title) (\(detail))" }
        if options.showStreaks, item.streak > 0 {
            return "\(item.title) (\(item.streak)-\(runUnit(item)) run at stake)"
        }
        return item.title
    }

    /// "day", "week" or "cycle" from a streak's unit ("days", "wks").
    private func runUnit(_ item: DailyReport.Item) -> String {
        if item.streakUnit.hasPrefix("wk") { return "week" }
        if item.streakUnit.hasPrefix("cycle") { return "cycle" }
        return "day"
    }

    /// "Workout (2/4 this week)".
    private func offPhrase(_ item: DailyReport.Item) -> String {
        item.detail.map { "\(item.title) (\($0))" } ?? item.title
    }
}
