import SwiftUI

/// The report's Timeline layout: the day in the order it was logged, a node
/// per log on a line down the leading edge with its time beside it. What is
/// still open (or was missed) follows with hollow nodes, then anything done
/// with no time that day, and a weekly habit's day off closes it in one
/// quiet line. Painted fills only, so `ImageRenderer` draws it.
struct ReportTimeline: View {
    let report: DailyReport
    let options: ReportOptions
    let palette: ReportPalette

    /// Nodes listed before "+N more", so a busy day keeps the card a
    /// sensible height in a chat.
    static let maxNodes = 10

    private let railWidth: CGFloat = 12
    private let node: CGFloat = 10
    private let timeColumn: CGFloat = 62
    private let glyphColumn: CGFloat = 20
    /// Half the gap between two rows, kept inside each row so the line
    /// runs unbroken from one node to the next.
    private let rowPadding: CGFloat = 7

    /// Where a node's centre sits under its row's top: about the middle of
    /// the title's first line.
    private var nodeCentre: CGFloat { rowPadding + 9 }
    /// Where the eyebrows and the quiet lines start: the time column.
    private var textInset: CGFloat { railWidth + 10 }

    var body: some View {
        let day = report.date.dayRange
        let timed = report.items
            .filter { time(of: $0, in: day) != nil }
            .sorted { ($0.loggedAt ?? .distantPast) < ($1.loggedAt ?? .distantPast) }
        let open = report.items.filter { $0.status == .open || $0.status == .missed }
        let untimed = report.items.filter { $0.isDone && time(of: $0, in: day) == nil }
        let off = report.items.filter { !$0.status.isExpected }

        let shownTimed = Array(timed.prefix(Self.maxNodes))
        let shownOpen = Array(open.prefix(Self.maxNodes - shownTimed.count))
        let shownUntimed = Array(untimed.prefix(Self.maxNodes - shownTimed.count - shownOpen.count))
        let hidden = timed.count + open.count + untimed.count - shownTimed.count - shownOpen.count - shownUntimed.count

        VStack(alignment: .leading, spacing: 14) {
            if report.items.isEmpty {
                Text("No habits on this card")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
            }
            if !shownTimed.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(shownTimed.enumerated()), id: \.element.id) { index, item in
                        row(item, time: item.loggedAt)
                            .background(alignment: .topLeading) {
                                rail(isFirst: index == 0, isLast: index == shownTimed.count - 1)
                            }
                    }
                }
            }
            if !shownOpen.isEmpty {
                section(report.isToday ? "Still open" : "Missed", items: shownOpen)
            }
            if !shownUntimed.isEmpty {
                section("Also done", items: shownUntimed)
            }
            if hidden > 0 {
                Text("+\(hidden) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondary)
                    .padding(.leading, textInset)
            }
            if !off.isEmpty {
                Text(offLine(off))
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
                    .lineLimit(2)
                    .padding(.leading, textInset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// When a done habit was logged, if that was on the card's day; a log
    /// added later for it has no place on the line.
    private func time(of item: DailyReport.Item, in day: Range<Date>) -> Date? {
        guard item.isDone, let time = item.loggedAt, day.contains(time) else { return nil }
        return time
    }

    /// "Off today: Gym, Swim", for weekly habits not logged that day.
    private func offLine(_ items: [DailyReport.Item]) -> String {
        let names = items.map(\.title).joined(separator: ", ")
        return "\(report.isToday ? "Off today" : "Off that day"): \(names)"
    }

    // MARK: - Rows

    private func section(_ title: String, items: [DailyReport.Item]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .eyebrowStyle(palette.secondary)
                .padding(.leading, textInset)
            ForEach(items) { row($0, time: nil) }
        }
    }

    /// A node, the time, the glyph, and the title with its detail and note
    /// under it; the run trails when the card shows runs.
    private func row(_ item: DailyReport.Item, time: Date?) -> some View {
        let tint = palette.habitTint(item.colorHex)

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            nodeMark(item.status, tint: tint)
                .frame(width: node, height: node)
                .frame(width: railWidth)
                // Level with the middle of the title's first line.
                .alignmentGuide(.firstTextBaseline) { $0.height / 2 + 5 }
                .padding(.trailing, 10)

            Group {
                if let time {
                    Text(time.formatted(.dateTime.hour().minute()))
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Color.clear.frame(height: 1)
                }
            }
            .frame(width: timeColumn, alignment: .leading)

            Image(systemName: item.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: glyphColumn)
                .padding(.trailing, 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink.opacity(item.isDone ? 1 : 0.7))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                if let detail = item.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if options.showNotes, let note = item.note {
                    Text("“\(note)”")
                        .font(.caption.italic())
                        .foregroundStyle(palette.ink.opacity(0.8))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if options.showStreaks, item.streak > 0 {
                Text("\(item.streak) \(item.streakUnit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .padding(.leading, 8)
            }
        }
        .padding(.vertical, rowPadding)
    }

    /// Logged is filled in the habit's colour, open a ring in it, and
    /// missed a quiet ring, never red.
    @ViewBuilder
    private func nodeMark(_ status: DayStatus, tint: Color) -> some View {
        switch status {
        case .done:
            Circle().fill(tint)
        case .open:
            Circle().strokeBorder(tint, lineWidth: 1.5)
        case .missed, .flexible, .resting:
            Circle().strokeBorder(palette.faint, lineWidth: 1.5)
        }
    }

    /// One row's stretch of the line: down to its node unless it is the
    /// first, on from it unless it is the last. The filled node covers the
    /// joint.
    private func rail(isFirst: Bool, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(palette.rule)
                .frame(width: 2, height: nodeCentre)
                .opacity(isFirst ? 0 : 1)
            Rectangle()
                .fill(palette.rule)
                .frame(width: 2)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: railWidth)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ReportTimeline(report: .sample, options: ReportOptions(), palette: ReportPalette(options: ReportOptions()))
        .frame(width: 342)
        .padding()
        .background(Color.black)
}
#endif
