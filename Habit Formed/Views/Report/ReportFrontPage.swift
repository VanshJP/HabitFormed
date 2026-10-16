import SwiftUI

/// The report's Front page layout: the day as a newspaper. A masthead, a
/// headline and the line under it written from the day (`ReportHeadline`),
/// what got done and what is still open in two columns, the Apple Health
/// numbers boxed as "By the numbers", and a ticker of each run, up when kept
/// today and down while at stake. It is the whole image, newsprint whatever
/// the card's background. Painted fills only, so `ImageRenderer` draws it.
struct ReportFrontPage: View {
    let report: DailyReport
    let options: ReportOptions

    private let ink = AppColors.newsInk
    private var soft: Color { AppColors.newsInk.opacity(0.72) }
    private var hairline: Color { AppColors.newsInk.opacity(0.35) }

    var body: some View {
        let shown = Array(report.items.prefix(ReportCardView.maxItems))
        let done = shown.filter(\.isDone)
        let open = shown.filter { $0.status == .open || $0.status == .missed }
        let off = shown.filter { $0.status == .flexible }
        let lines = report.health.lines(showing: options.metrics)

        VStack(alignment: .leading, spacing: 14) {
            dateline
            masthead
            VStack(alignment: .leading, spacing: 8) {
                Text(ReportHeadline.headline(for: report))
                    .font(.custom("Didot-Bold", size: 28))
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(ReportHeadline.dek(for: report, showsCalories: options.shows(.calories)))
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundStyle(soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            columns(done: done, open: open)
            if !off.isEmpty {
                Text("Off today: " + off.map { item in item.detail.map { "\(item.title) (\($0))" } ?? item.title }.joined(separator: ", "))
                    .font(.system(size: 12.5, design: .serif))
                    .foregroundStyle(soft)
            }
            if report.items.count > shown.count {
                Text("+\(report.items.count - shown.count) more inside")
                    .font(.system(size: 12.5, design: .serif).italic())
                    .foregroundStyle(soft)
            }
            note
            if !lines.isEmpty { numbers(lines) }
            footer
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .frame(width: ReportCardView.width, alignment: .leading)
        .background(AppColors.newsprint)
    }

    // MARK: - Masthead

    private var dateline: some View {
        HStack {
            Text(report.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
            Spacer(minLength: 8)
            if !report.name.isEmpty { Text("\(report.name) edition") }
        }
        .font(.system(size: 10, weight: .medium, design: .serif))
        .textCase(.uppercase)
        .kerning(1.2)
        .lineLimit(1)
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(ink).frame(height: 1) }
    }

    private var masthead: some View {
        VStack(spacing: 6) {
            Text("The Daily Habit")
                .font(.custom("Didot-Bold", size: 40))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            VStack(spacing: 2) {
                Rectangle().fill(ink).frame(height: 3)
                Rectangle().fill(ink).frame(height: 1)
            }
            HStack {
                Text("\(report.done) of \(report.expected) done")
                Spacer(minLength: 6)
                Text("\(report.percentText) of the day")
                if options.shows(.sleep), let hours = report.health.sleepHours {
                    Spacer(minLength: 6)
                    Text("Slept \(ReportFormat.duration(minutes: hours * 60))")
                }
            }
            .font(.system(size: 10.5, weight: .medium, design: .serif))
            .textCase(.uppercase)
            .kerning(1)
            .lineLimit(1)
        }
    }

    // MARK: - Columns

    private func columns(done: [DailyReport.Item], open: [DailyReport.Item]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            column(title: "Done", items: done, empty: "Nothing yet")
                .padding(.trailing, 14)
                .overlay(alignment: .trailing) { Rectangle().fill(hairline).frame(width: 1) }
            column(title: report.isToday ? "Still open" : "Missed", items: open, empty: "All clear")
                .padding(.leading, 14)
        }
        .padding(.top, 12)
        .overlay(alignment: .top) { Rectangle().fill(ink).frame(height: 1) }
    }

    private func column(title: String, items: [DailyReport.Item], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold, design: .serif))
                .textCase(.uppercase)
                .kerning(1.6)
                .foregroundStyle(AppColors.newsRed)
            if items.isEmpty {
                Text(empty)
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundStyle(soft)
            }
            ForEach(items) { entry($0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func entry(_ item: DailyReport.Item) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Rectangle()
                .fill(item.isDone ? ink : .clear)
                .overlay { Rectangle().strokeBorder(ink, lineWidth: 1.5) }
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                if let line = line(for: item) {
                    Text(line)
                        .font(.system(size: 12.5, design: .serif))
                        .foregroundStyle(soft)
                }
                if !item.isDone, let progress = item.progress {
                    Rectangle()
                        .fill(ink.opacity(0.15))
                        .frame(width: 110, height: 4)
                        .overlay(alignment: .leading) { Rectangle().fill(ink).frame(width: 110 * progress) }
                }
            }
        }
    }

    /// "Day 3 of the run", "2/5 this week", "2-day run at stake", "Not yet today".
    private func line(for item: DailyReport.Item) -> String? {
        if item.isDone {
            if let detail = item.detail { return detail }
            guard options.showStreaks, item.streak > 0 else { return nil }
            return "\(item.streakUnit.hasPrefix("wk") ? "Week" : "Day") \(item.streak) of the run"
        }
        if let detail = item.detail { return detail }
        if options.showStreaks, item.streak > 0 {
            return "\(item.streak)-\(item.streakUnit.hasPrefix("wk") ? "week" : "day") run at stake"
        }
        return report.isToday ? "Not yet today" : nil
    }

    // MARK: - The rest

    @ViewBuilder
    private var note: some View {
        let text = options.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text("Editor’s note")
                    .font(.system(size: 10.5, weight: .semibold, design: .serif))
                    .textCase(.uppercase)
                    .kerning(1.6)
                    .foregroundStyle(AppColors.newsRed)
                Text(text)
                    .font(.system(size: 14, design: .serif).italic())
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func numbers(_ lines: [HealthLine]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("By the numbers")
                .font(.system(size: 10.5, weight: .semibold, design: .serif))
                .textCase(.uppercase)
                .kerning(1.6)
                .padding(.bottom, 2)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(line.label)
                        .padding(.leading, line.isPart ? 12 : 0)
                    DottedLeader()
                        .stroke(ink.opacity(0.45), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [0.1, 3]))
                        .frame(height: 1)
                    Text(line.value)
                        .monospacedDigit()
                }
                .font(.system(size: 13.5, weight: line.isPart ? .regular : .medium, design: .serif))
                .foregroundStyle(line.isPart ? soft : ink)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay { Rectangle().strokeBorder(ink, lineWidth: 1.5) }
    }

    /// The ticker of runs, then the key and the paper's name, full bleed.
    private var footer: some View {
        VStack(spacing: 0) {
            if options.showStreaks, !tickerText.isEmpty {
                Text(tickerText)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(AppColors.newsprint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 24)
                    .background(ink)
            }
            HStack {
                if options.showStreaks, !tickerText.isEmpty {
                    Text("▲ run kept today, ▼ run at stake")
                }
                Spacer(minLength: 8)
                Text("Habit Formed")
            }
            .font(.system(size: 10.5, design: .serif))
            .foregroundStyle(soft)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, -24)
        .padding(.top, 4)
    }

    /// "READ 3▲  CREA 3▲  RLM 2▼": each run going, up if kept today.
    private var tickerText: String {
        report.items.compactMap { item -> String? in
            guard item.streak > 0 || item.isDone else { return nil }
            let mark = item.isDone ? "▲" : (item.status == .open || item.status == .missed ? "▼" : "")
            return "\(Self.symbol(for: item.title)) \(item.streak)\(mark)"
        }
        .joined(separator: "  ")
    }

    /// A ticker symbol: a short name whole, a long one's first four letters,
    /// several words by their initials.
    static func symbol(for title: String) -> String {
        let words = title.split(whereSeparator: \.isWhitespace)
        if words.count > 1 { return words.compactMap(\.first).map(String.init).joined().uppercased() }
        return (title.count <= 5 ? title : String(title.prefix(4))).uppercased()
    }
}

/// A straight line across the middle of its frame, dotted by its stroke.
private struct DottedLeader: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
