import SwiftUI

/// The report's Sundial layout: the day as a 24-hour dial, midnight at the
/// top. Each habit logged sits as a bead at the time it was logged, named
/// along a spoke from the centre; the night's sleep and the day's workouts
/// run as bands round the rim (when the card shows them), and today's dial
/// has a hand at now with the rest of the day dashed. What is still open is
/// listed under it. Painted fills only, so `ImageRenderer` draws it.
struct ReportSundial: View {
    let report: DailyReport
    let options: ReportOptions
    let palette: ReportPalette

    private let size: CGFloat = 320
    private let rim: CGFloat = 150
    /// Where a spoke's name starts and ends.
    private let spoke: ClosedRange<CGFloat> = 62...138
    /// Spokes closer than this many minutes would touch near the centre.
    private let spacing: Double = 45

    var body: some View {
        let day = report.date.startOfDay
        let timed = report.items
            .compactMap { item in item.loggedAt.flatMap { minute(of: $0, from: day) }.map { (item: item, minute: $0) } }
            .sorted { $0.minute < $1.minute }
        let open = report.items.filter { $0.status == .open || $0.status == .missed }
        let untimed = report.items.filter { item in item.isDone && !timed.contains { $0.item.id == item.id } }

        VStack(alignment: .leading, spacing: 16) {
            dial(timed: timed, day: day)
                .frame(width: size, height: size)
                .frame(maxWidth: .infinity)
            legend(day: day)
            if !open.isEmpty || !untimed.isEmpty {
                list(open: open, untimed: untimed)
            }
        }
    }

    // MARK: - Dial

    private func dial(timed: [(item: DailyReport.Item, minute: Double)], day: Date) -> some View {
        let spokes = Self.spread(timed.map(\.minute), gap: spacing)
        let now = report.isToday ? minute(of: Date(), from: day) : nil

        return ZStack {
            Circle()
                .fill(palette.well)
                .frame(width: size - 8, height: size - 8)
            DialTicks(major: false).stroke(palette.rule, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            DialTicks(major: true).stroke(palette.faint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            ForEach(Array(["12a", "6a", "12p", "6p"].enumerated()), id: \.offset) { index, hour in
                Text(hour)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.secondary)
                    .position(point(Double(index) * 360, radius: 126))
            }

            bands(day: day, now: now)

            if let now {
                Path { path in
                    path.move(to: point(now, radius: spoke.lowerBound - 4))
                    path.addLine(to: point(now, radius: rim - 10))
                }
                .stroke(palette.ink.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                Circle()
                    .fill(palette.ink.opacity(0.8))
                    .frame(width: 6, height: 6)
                    .position(point(now, radius: rim - 10))
            }

            ForEach(Array(timed.enumerated()), id: \.offset) { index, entry in
                // A spoke nudged off its bead keeps a hairline back to it.
                if abs(spokes[index] - entry.minute) > 1 {
                    Path { path in
                        path.move(to: point(entry.minute, radius: rim - 7))
                        path.addLine(to: point(spokes[index], radius: spoke.upperBound + 2))
                    }
                    .stroke(palette.faint, lineWidth: 1)
                }
                Circle()
                    .fill(Color(hex: entry.item.colorHex))
                    .frame(width: 13, height: 13)
                    .position(point(entry.minute, radius: rim))
                label(entry.item, at: spokes[index])
            }

            VStack(spacing: 2) {
                Text("\(report.done)/\(report.expected)")
                    .font(.system(size: 34, weight: .bold, design: options.font.numerals).monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(centreCaption(timed: timed))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
            }
            .frame(width: (spoke.lowerBound - 6) * 2)
        }
    }

    /// Sleep and workouts on the rim while the card shows them, and the rest
    /// of today dashed.
    @ViewBuilder
    private func bands(day: Date, now: Double?) -> some View {
        if options.shows(.sleep), let sleep = report.health.sleepSpan {
            DayArc(from: minute(sleep.start, from: day), to: minute(sleep.end, from: day), radius: rim)
                .stroke(palette.dataTint(AppColors.info).opacity(0.75), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        }
        if options.shows(.exercise) {
            ForEach(report.health.workoutSpans, id: \.self) { span in
                DayArc(from: minute(span.start, from: day), to: minute(span.end, from: day), radius: rim)
                    .stroke(palette.ink.opacity(0.75), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            }
        }
        if let now {
            DayArc(from: now, to: 1440, radius: rim)
                .stroke(palette.ink.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
        }
    }

    /// The habit's name and time along its spoke, read upright on either
    /// side: outward on the right half, inward on the left.
    private func label(_ item: DailyReport.Item, at minute: Double) -> some View {
        let length = spoke.upperBound - spoke.lowerBound
        let mid = (spoke.lowerBound + spoke.upperBound) / 2
        let angle = minute / 1440 * 360 - 90
        let rightHalf = minute.truncatingRemainder(dividingBy: 1440) < 720
        return HStack(spacing: 3) {
            Text(item.title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(palette.ink)
            if let time = item.loggedAt {
                Text(time.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: length, alignment: rightHalf ? .leading : .trailing)
        .rotationEffect(.degrees(rightHalf ? angle : angle + 180))
        .position(point(minute, radius: mid))
    }

    private func centreCaption(timed: [(item: DailyReport.Item, minute: Double)]) -> String {
        guard report.isToday else { return "of the day" }
        guard let last = timed.last?.item.loggedAt else { return "so far" }
        return "done by \(last.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Under the dial

    @ViewBuilder
    private func legend(day: Date) -> some View {
        let sleep = options.shows(.sleep) && report.health.sleepSpan != nil
        let moved = options.shows(.exercise) && !report.health.workoutSpans.isEmpty
        if sleep || moved || report.isToday {
            HStack(spacing: 16) {
                if sleep, let hours = report.health.sleepHours {
                    key("\(ReportFormat.duration(minutes: hours * 60)) asleep") {
                        Capsule().fill(palette.dataTint(AppColors.info).opacity(0.75)).frame(width: 14, height: 5)
                    }
                }
                if moved {
                    key("Workouts") {
                        Capsule().fill(palette.ink.opacity(0.75)).frame(width: 14, height: 5)
                    }
                }
                if report.isToday {
                    key("Rest of today") {
                        Capsule()
                            .stroke(palette.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                            .frame(width: 14, height: 1.5)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func key<Mark: View>(_ text: String, @ViewBuilder mark: () -> Mark) -> some View {
        HStack(spacing: 6) {
            mark()
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.secondary)
        }
    }

    /// What the dial cannot place: habits still open, and any done with no
    /// time on this day (a log added later).
    private func list(open: [DailyReport.Item], untimed: [DailyReport.Item]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if !open.isEmpty {
                Text(report.isToday ? "Still open" : "Missed")
                    .eyebrowStyle(palette.secondary)
                ForEach(open) { row($0) }
            }
            if !untimed.isEmpty {
                Text("Also done")
                    .eyebrowStyle(palette.secondary)
                ForEach(untimed) { row($0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ item: DailyReport.Item) -> some View {
        let tint = palette.habitTint(item.colorHex)
        return HStack(spacing: 10) {
            Circle()
                .strokeBorder(tint, lineWidth: 2)
                .background(Circle().fill(item.isDone ? tint : .clear))
                .frame(width: 11, height: 11)
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let progress = item.progress, !item.isDone {
                Capsule()
                    .fill(palette.well)
                    .frame(width: 56, height: 5)
                    .overlay(alignment: .leading) {
                        Capsule().fill(tint).frame(width: max(56 * progress, 5), height: 5)
                    }
            }
            Text(rowDetail(item))
                .font(.caption)
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
        }
    }

    private func rowDetail(_ item: DailyReport.Item) -> String {
        if let detail = item.detail { return detail }
        if !item.isDone, item.streak > 0 { return "\(item.streak)-\(item.streakUnit.hasPrefix("wk") ? "week" : "day") run at stake" }
        return item.isDone ? "Done" : "Not yet"
    }

    // MARK: - Geometry

    /// Minutes from the day's midnight; a night's sleep starts before zero.
    private func minute(_ date: Date, from day: Date) -> Double {
        date.timeIntervalSince(day) / 60
    }

    /// Minutes into the day, or nil for a log made on another day.
    private func minute(of date: Date, from day: Date) -> Double? {
        let value = minute(date, from: day)
        return (0..<1440).contains(value) ? value : nil
    }

    private func point(_ minute: Double, radius: CGFloat) -> CGPoint {
        DayArc.point(minute: minute, radius: radius, in: CGRect(x: 0, y: 0, width: size, height: size))
    }

    /// Minutes in order, each pushed at least `gap` past the one before, so
    /// spokes never sit closer than that.
    static func spread(_ minutes: [Double], gap: Double) -> [Double] {
        var placed: [Double] = []
        for minute in minutes {
            placed.append(max(minute, (placed.last ?? -.infinity) + gap))
        }
        return placed
    }
}

// MARK: - Shapes

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
    static func point(minute: Double, radius: CGFloat, in rect: CGRect) -> CGPoint {
        let angle = CGFloat(minute / 1440) * 2 * .pi - .pi / 2
        return CGPoint(x: rect.midX + radius * cos(angle), y: rect.midY + radius * sin(angle))
    }
}

/// The dial's hour ticks: the four quarters long, the other hours short.
private struct DialTicks: Shape {
    let major: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let outer = min(rect.width, rect.height) / 2 - 6
        for hour in 0..<24 where hour.isMultiple(of: 6) == major {
            let minute = Double(hour * 60)
            path.move(to: DayArc.point(minute: minute, radius: outer, in: rect))
            path.addLine(to: DayArc.point(minute: minute, radius: outer - (major ? 12 : 6), in: rect))
        }
        return path
    }
}
