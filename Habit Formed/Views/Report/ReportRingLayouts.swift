import SwiftUI

// The day's ring every card shares, and the two layouts built of rings
// (`ReportLayout.rings`, `.orbit`). Painted fills only, like the rest of the
// card, so `ImageRenderer` draws them.

// MARK: - Day ring

/// The day's count in a ring cut into an arc per habit the day expected,
/// each in its habit's colour once done. Done arcs come first, so the ring
/// fills clockwise like a progress ring and closes in every colour on a
/// perfect day.
struct ReportDayRing<Center: View>: View {
    let report: DailyReport
    let palette: ReportPalette
    let diameter: CGFloat
    let lineWidth: CGFloat
    @ViewBuilder var center: Center

    var body: some View {
        let expected = report.items.filter { $0.status.isExpected }
        let arcs = expected.filter(\.isDone) + expected.filter { !$0.isDone }
        let share = 1 / CGFloat(max(arcs.count, 1))
        // Round caps reach half the line past each end, so each arc is
        // trimmed back far enough to leave a hair between it and the next.
        let circumference = CGFloat.pi * (diameter - lineWidth)
        let margin = arcs.count > 1 ? min((lineWidth / 2 + 1.5) / circumference, share * 0.4) : 0

        ZStack {
            if arcs.isEmpty {
                Circle().stroke(palette.rule, lineWidth: lineWidth)
            }
            ForEach(arcs.indices, id: \.self) { index in
                Circle()
                    .trim(from: CGFloat(index) * share + margin, to: CGFloat(index + 1) * share - margin)
                    .stroke(
                        arcs[index].isDone ? palette.habitTint(arcs[index].colorHex) : palette.rule,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            center
        }
        .padding(lineWidth / 2)
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

// MARK: - Rings

/// The last seven days as rings, one per habit from the outside in, each cut
/// into seven arcs with today's ending at the top: logged days in the habit's
/// colour, today's at full strength. The day's count sits in the middle, the
/// weekdays round the edge, and the habits are named beside it in ring order.
struct ReportRings: View {
    let report: DailyReport
    let palette: ReportPalette
    let showStreaks: Bool
    var numerals: Font.Design = .rounded

    /// Past this many, rings would be too thin to read.
    static let maxRings = 8
    private let diameter: CGFloat = 196
    /// The outer ring's edge, leaving room round it for the weekday letters.
    private let outerRadius: CGFloat = 82
    private let holeRadius: CGFloat = 30

    var body: some View {
        let shown = Array(report.items.prefix(Self.maxRings))
        let step = min(16, (outerRadius - holeRadius) / CGFloat(max(shown.count, 1)))
        let lineWidth = step * 0.7

        HStack(alignment: .center, spacing: 14) {
            ZStack {
                weekdays
                ForEach(shown.indices, id: \.self) { index in
                    ring(shown[index], radius: outerRadius - step * CGFloat(index) - lineWidth / 2, lineWidth: lineWidth)
                }
                Text("\(report.done)/\(report.expected)")
                    .font(.system(size: 17, weight: .bold, design: numerals).monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: holeRadius * 2 - 6)
            }
            .frame(width: diameter, height: diameter)

            legend(shown)
        }
    }

    /// Each day's letter over the middle of its arc, today's in bold.
    private var weekdays: some View {
        ForEach(0..<7, id: \.self) { index in
            let angle = (CGFloat(index) + 0.5) / 7 * 2 * .pi - .pi / 2
            Text(report.date.adding(days: index - 6).formatted(.dateTime.weekday(.narrow)))
                .font(.system(size: 9, weight: index == 6 ? .heavy : .semibold))
                .foregroundStyle(index == 6 ? palette.ink : palette.faint)
                .offset(x: (outerRadius + 9) * cos(angle), y: (outerRadius + 9) * sin(angle))
        }
    }

    private func ring(_ item: DailyReport.Item, radius: CGFloat, lineWidth: CGFloat) -> some View {
        let tint = palette.habitTint(item.colorHex)
        let margin = (lineWidth / 2 + 1) / (2 * .pi * radius)
        return ZStack {
            ForEach(0..<7, id: \.self) { day in
                let logged = item.week.indices.contains(day) && item.week[day]
                Circle()
                    .trim(from: CGFloat(day) / 7 + margin, to: CGFloat(day + 1) / 7 - margin)
                    .stroke(
                        logged ? tint.opacity(day == 6 ? 1 : 0.55) : palette.rule,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: radius * 2, height: radius * 2)
    }

    private func legend(_ shown: [DailyReport.Item]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Last 7 days")
                .eyebrowStyle(palette.secondary)
            if shown.isEmpty {
                Text("No habits on this card.")
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
            }
            ForEach(shown) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(palette.habitTint(item.colorHex))
                        .frame(width: 7, height: 7)
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.ink.opacity(item.isDone ? 1 : 0.65))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if showStreaks, item.streak > 0 {
                        Text("\(item.streak)")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(palette.secondary)
                    }
                }
            }
            if report.items.count > shown.count {
                Text("+\(report.items.count - shown.count) more")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Orbit

/// The day as a small solar system: its ring in the middle, and each habit a
/// circle on an orbit round it, filled with its colour once done. With
/// streaks on, a habit kept longer is a bigger circle. The orbit's line
/// breaks for each circle, so nothing is drawn through one.
struct ReportOrbit: View {
    let report: DailyReport
    let palette: ReportPalette
    let showStreaks: Bool
    var numerals: Font.Design = .rounded

    private let orbit: CGFloat = 122
    private let side: CGFloat = 300

    var body: some View {
        let shown = Array(report.items.prefix(ReportCardView.maxItems))

        VStack(spacing: 16) {
            ZStack {
                path(shown)
                ReportDayRing(report: report, palette: palette, diameter: 136, lineWidth: 12) {
                    VStack(spacing: 0) {
                        Text("\(report.done)/\(report.expected)")
                            .font(.system(size: 32, weight: .bold, design: numerals).monospacedDigit())
                            .foregroundStyle(palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(report.percentText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(palette.secondary)
                    }
                    .padding(.horizontal, 16)
                }
                ForEach(shown.indices, id: \.self) { index in
                    let angle = CGFloat(index) / CGFloat(shown.count) * 2 * .pi - .pi / 2
                    planet(shown[index])
                        .offset(x: orbit * cos(angle), y: orbit * sin(angle))
                }
            }
            .frame(width: side, height: side)

            VStack(spacing: 4) {
                Text(report.verdict)
                    .font(.title2.bold())
                    .foregroundStyle(palette.ink)
                if showStreaks, report.perfectStreak > 0 {
                    Text(report.perfectStreak == 1 ? "1 perfect day" : "\(report.perfectStreak) perfect days in a row")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.ink.opacity(0.85))
                }
                if report.items.count > shown.count {
                    Text("+\(report.items.count - shown.count) more")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func size(of item: DailyReport.Item) -> CGFloat {
        showStreaks ? 34 + CGFloat(min(item.streak, 14)) : 42
    }

    /// The orbit as arcs from one circle to the next, each stopping 4pt
    /// short of the circles at its ends.
    private func path(_ shown: [DailyReport.Item]) -> some View {
        let count = shown.count
        let circumference = 2 * .pi * orbit
        func clearance(_ index: Int) -> CGFloat {
            (size(of: shown[index % count]) / 2 + 4) / circumference
        }
        return ZStack {
            if count == 0 {
                Circle().stroke(palette.rule, lineWidth: 1)
            }
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .trim(
                        from: CGFloat(index) / CGFloat(count) + clearance(index),
                        to: CGFloat(index + 1) / CGFloat(count) - clearance(index + 1)
                    )
                    .stroke(palette.rule, lineWidth: 1)
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: orbit * 2, height: orbit * 2)
    }

    private func planet(_ item: DailyReport.Item) -> some View {
        let tint = palette.habitTint(item.colorHex)
        let width = size(of: item)
        return Image(systemName: item.symbol)
            .font(.system(size: width * 0.38, weight: .semibold))
            .foregroundStyle(item.isDone ? .white : tint)
            .frame(width: width, height: width)
            .background {
                ZStack {
                    if item.isDone {
                        Circle().fill(Color(hex: item.colorHex))
                    } else {
                        Circle().fill(palette.well)
                        Circle().strokeBorder(tint.opacity(0.6), lineWidth: 1.5)
                    }
                }
            }
            .accessibilityLabel("\(item.title), \(item.isDone ? "done" : "not done")")
    }
}
