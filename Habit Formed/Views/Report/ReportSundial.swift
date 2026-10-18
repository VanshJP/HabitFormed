import SwiftUI

/// The report's Sundial layout: the day as a 24-hour dial, midnight at the
/// top. Logs made close together gather into one numbered bead at the time
/// of the first (`SundialMoment`), its colours shared between the habits
/// logged then, and the key under the dial names them. The night's sleep and
/// the day's workouts run as thin bands round the rim (when the card shows
/// them), and today's dial has a hand at now, the hours after it fainter.
/// Painted fills only, so `ImageRenderer` draws it.
struct ReportSundial: View {
    let report: DailyReport
    let options: ReportOptions
    let palette: ReportPalette

    private let size: CGFloat = 320
    /// From the outside in: the bands, the beads, the hour dots, the hours.
    private let bandRadius: CGFloat = 152
    private let beadRadius: CGFloat = 139
    private let dotRadius: CGFloat = 122
    private let numeralRadius: CGFloat = 104
    /// Where the hand starts, clear of the count in the middle.
    private let handStart: CGFloat = 64
    private let bead: CGFloat = 20
    /// A log within this many minutes of a moment's first joins its bead;
    /// moments this far apart sit a bead's width apart on the rim.
    private let window: Double = 40

    var body: some View {
        let day = report.date.startOfDay
        let logs = report.items
            .compactMap { item in
                item.loggedAt.flatMap { date in
                    minute(of: date, from: day).map { SundialMoment.Log(item: item, minute: $0, time: date) }
                }
            }
            .sorted { $0.minute < $1.minute }
        let moments = SundialMoment.group(logs, window: window)
        let untimed = report.items.filter { item in item.isDone && !logs.contains { $0.item.id == item.id } }

        VStack(alignment: .leading, spacing: 16) {
            dial(moments: moments, last: logs.last?.time, day: day)
                .frame(width: size, height: size)
                .frame(maxWidth: .infinity)
            ReportSundialKey(report: report, options: options, palette: palette, moments: moments, untimed: untimed)
        }
    }

    // MARK: - Dial

    private func dial(moments: [SundialMoment], last: Date?, day: Date) -> some View {
        let now = report.isToday ? minute(of: Date(), from: day) : nil

        return ZStack {
            Circle()
                .fill(palette.well)
                .frame(width: size - 8, height: size - 8)
            bands(day: day)
            HourDots(radius: dotRadius, now: now, later: false)
                .fill(palette.faint)
            HourDots(radius: dotRadius, now: now, later: true)
                .fill(palette.rule)
            ForEach(Array(["12a", "6a", "12p", "6p"].enumerated()), id: \.offset) { index, hour in
                Text(hour)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.secondary)
                    .position(point(Double(index) * 360, radius: numeralRadius))
            }

            if let now {
                Path { path in
                    path.move(to: point(now, radius: handStart))
                    path.addLine(to: point(now, radius: dotRadius))
                }
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                Circle()
                    .fill(palette.accent)
                    .frame(width: 6, height: 6)
                    .position(point(now, radius: dotRadius))
            }

            ForEach(moments) { moment in
                SundialBead(moment: moment, diameter: bead)
                    .position(point(moment.minute, radius: beadRadius))
            }

            VStack(spacing: 2) {
                Text(report.countText)
                    .font(.system(size: 34, weight: .bold, design: options.font.numerals).monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let caption = caption(last: last) {
                    Text(caption)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(width: handStart * 2 + 20)
        }
    }

    /// Sleep and workouts on the rim while the card shows them.
    @ViewBuilder
    private func bands(day: Date) -> some View {
        let style = StrokeStyle(lineWidth: 4, lineCap: .butt)
        if options.shows(.sleep), let sleep = report.health.sleepSpan {
            DayArc(from: minute(sleep.start, from: day), to: minute(sleep.end, from: day), radius: bandRadius)
                .stroke(Self.sleepTint(palette), style: style)
        }
        if options.shows(.exercise) {
            ForEach(report.health.workoutSpans, id: \.self) { span in
                DayArc(from: minute(span.start, from: day), to: minute(span.end, from: day), radius: bandRadius)
                    .stroke(Self.workoutTint(palette), style: style)
            }
        }
    }

    /// The bands' colours, shared with the key.
    static func sleepTint(_ palette: ReportPalette) -> Color {
        palette.dataTint(AppColors.info).opacity(0.7)
    }

    static func workoutTint(_ palette: ReportPalette) -> Color {
        palette.dataTint(AppColors.exerciseKinds[0]).opacity(0.7)
    }

    /// Under the count: when the last log was made.
    private func caption(last: Date?) -> String? {
        if let last { return "last log \(last.formatted(date: .omitted, time: .shortened))" }
        if report.expected == 0 { return nil }
        return report.isToday ? "so far" : "done"
    }

    // MARK: - Geometry

    /// The clock's minute of the day, as the dial's hours read it (so a day
    /// the clocks change on still puts 9 AM at 9); a night's sleep that
    /// starts the evening before counts back from zero.
    private func minute(_ date: Date, from day: Date) -> Double {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let clock = Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0)) + Double(parts.second ?? 0) / 60
        if date < day { return clock - 1440 }
        if date >= day.nextDayStart { return clock + 1440 }
        return clock
    }

    /// Minutes into the day, or nil for a log made on another day.
    private func minute(of date: Date, from day: Date) -> Double? {
        let value = minute(date, from: day)
        return (0..<1440).contains(value) ? value : nil
    }

    private func point(_ minute: Double, radius: CGFloat) -> CGPoint {
        DayArc.point(minute: minute, radius: radius, in: CGRect(x: 0, y: 0, width: size, height: size))
    }
}

// MARK: - Moments

/// Logs made close together, drawn as one bead: a moment starts at a log and
/// takes every later one within `window` minutes of it, so moments always
/// sit at least that far apart.
nonisolated struct SundialMoment: Identifiable, Sendable {
    nonisolated struct Log: Sendable {
        let item: DailyReport.Item
        let minute: Double
        let time: Date
    }

    /// Counted from 1 in the order logged: the bead's number and the key's.
    let number: Int
    let minute: Double
    let time: Date
    var items: [DailyReport.Item]

    var id: Int { number }

    /// `logs` in time order.
    static func group(_ logs: [Log], window: Double) -> [SundialMoment] {
        var moments: [SundialMoment] = []
        for log in logs {
            if let last = moments.last, log.minute - last.minute < window {
                moments[moments.count - 1].items.append(log.item)
            } else {
                moments.append(SundialMoment(number: moments.count + 1, minute: log.minute, time: log.time, items: [log.item]))
            }
        }
        return moments
    }
}

/// A moment's bead: a disc in its habit's colour, or shared in equal wedges
/// when several were logged then, with the moment's number in white.
struct SundialBead: View {
    let moment: SundialMoment
    let diameter: CGFloat

    var body: some View {
        let count = moment.items.count
        ZStack {
            ForEach(Array(moment.items.enumerated()), id: \.offset) { index, item in
                Wedge(
                    start: Double(index) / Double(max(count, 1)),
                    end: Double(index + 1) / Double(max(count, 1))
                )
                .fill(Color(hex: item.colorHex))
            }
            Text("\(moment.number)")
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Shapes

/// A slice of a disc from one share of a turn to another, clockwise from the
/// top; the whole turn is the whole disc.
private struct Wedge: Shape {
    let start: Double
    let end: Double

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        if end - start >= 1 {
            return Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
        }
        var path = Path()
        path.move(to: centre)
        path.addArc(
            center: centre,
            radius: radius,
            startAngle: .degrees(start * 360 - 90),
            endAngle: .degrees(end * 360 - 90),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

/// An arc round the dial from one minute of the day to another, clockwise
/// from midnight at the top, drawn in short straight steps.
private struct DayArc: Shape {
    let from: Double
    let to: Double
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = max(Int((to - from) / 4), 1)
        for step in 0...steps {
            let minute = from + (to - from) * Double(step) / Double(steps)
            let point = Self.point(minute: minute, radius: radius, in: rect)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    /// Where a minute of the day sits at `radius` from the centre of `rect`.
    nonisolated static func point(minute: Double, radius: CGFloat, in rect: CGRect) -> CGPoint {
        let angle = CGFloat(minute / 1440) * 2 * .pi - .pi / 2
        return CGPoint(x: rect.midX + radius * cos(angle), y: rect.midY + radius * sin(angle))
    }
}

/// A dot per hour, the four quarters larger: the hours up to `now` when
/// `later` is false, the ones after it when true (none without a now).
private struct HourDots: Shape {
    let radius: CGFloat
    let now: Double?
    let later: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for hour in 0..<24 {
            let isLater = now.map { Double(hour * 60) > $0 } ?? false
            guard isLater == later else { continue }
            let size: CGFloat = hour.isMultiple(of: 6) ? 4 : 2.5
            let centre = DayArc.point(minute: Double(hour * 60), radius: radius, in: rect)
            path.addEllipse(in: CGRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size))
        }
        return path
    }
}
