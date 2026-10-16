import SwiftUI

/// The report's Receipt layout: the day as a till receipt, and the image
/// sent is the slip alone, torn edges and all. A line per habit runs to its status
/// over dotted leaders, a dot of the habit's color before its name; then the
/// day's totals, any Apple Health numbers as line items, the verdict and a
/// barcode. It is the whole card, header and note included, and always
/// monospaced capitals: a receipt's own type, whatever the card's Type says.
/// Painted fills only, so `ImageRenderer` draws it.
struct ReportReceipt: View {
    let report: DailyReport
    let options: ReportOptions

    /// Paper's ink, whatever the card's background: the slip is always paper.
    private let ink = ReportPalette(look: nil)
    private let body13 = Font.system(size: 13, design: .monospaced)
    private let small = Font.system(size: 11, design: .monospaced)

    var body: some View {
        let shown = Array(report.items.prefix(ReportCardView.maxItems))
        let health = healthLines

        VStack(alignment: .leading, spacing: 14) {
            header
            rule
            VStack(alignment: .leading, spacing: 9) {
                if shown.isEmpty {
                    Text("No habits on this card")
                        .foregroundStyle(ink.secondary)
                }
                ForEach(shown) { itemLine($0) }
                if report.items.count > shown.count {
                    Text("+\(report.items.count - shown.count) more")
                        .foregroundStyle(ink.secondary)
                }
            }
            rule
            VStack(spacing: 6) {
                amount("Habits done", "\(report.done)/\(report.expected)")
                if options.showStreaks, report.perfectStreak > 0 {
                    amount("Perfect days in a row", "\(report.perfectStreak)")
                }
                ForEach(health, id: \.label) { amount($0.label, $0.value) }
            }
            rule
            HStack {
                Text("Total")
                Spacer()
                Text(report.percentText)
            }
            .font(.system(size: 17, weight: .bold, design: .monospaced))
            footer
        }
        .font(body13)
        // Nearer the text than the card's own `fontDesign`, so it wins.
        .fontDesign(.monospaced)
        .foregroundStyle(ink.ink)
        .textCase(.uppercase)
        .padding(.horizontal, 20)
        .padding(.vertical, 24 + ReceiptSlip.depth)
        .background(ink.paper, in: ReceiptSlip())
        // A faint edge, so the slip stands off a white chat as well as a
        // dark one.
        .overlay { ReceiptSlip().stroke(ink.rule, lineWidth: 1) }
    }

    /// The store mark in the card's accent; a picked accent prints as is,
    /// since the slip is light whatever the background.
    private var markTint: Color {
        options.accentHex.isEmpty ? (options.look?.accent ?? AppColors.primary) : Color(hex: options.accentHex)
    }

    // MARK: - Parts

    private var header: some View {
        VStack(spacing: 4) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 22))
                .foregroundStyle(markTint)
            Text("Habit Formed")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
            Text(report.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()))
                .foregroundStyle(ink.secondary)
            if !report.name.isEmpty {
                Text("Report for \(report.name)")
                    .foregroundStyle(ink.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var rule: some View {
        Leader()
            .stroke(ink.faint, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .frame(height: 1)
    }

    private func itemLine(_ item: DailyReport.Item) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Circle()
                    .fill(Color(hex: item.colorHex))
                    .frame(width: 7, height: 7)
                    .alignmentGuide(.lastTextBaseline) { $0[.bottom] + 1 }
                Text(item.title)
                    .lineLimit(1)
                    .layoutPriority(1)
                Leader()
                    .stroke(ink.faint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.1, 4]))
                    .frame(minWidth: 12)
                    .frame(height: 2)
                Text(statusWord(item.status))
                    .fontWeight(item.isDone ? .bold : .regular)
                    .foregroundStyle(item.isDone ? ink.ink : ink.secondary)
                    .layoutPriority(1)
            }
            if let detail = detailLine(item) {
                Text(detail)
                    .font(small)
                    .foregroundStyle(ink.secondary)
                    .lineLimit(1)
                    .padding(.leading, 13)
            }
        }
    }

    private func amount(_ label: String, _ value: String) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(label)
                .foregroundStyle(ink.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
    }

    private var footer: some View {
        let note = options.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(spacing: 10) {
            Text(report.verdict)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
            if !note.isEmpty {
                Text(note)
                    .textCase(nil)
                    .italic()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Barcode(seed: UInt64(max(report.date.timeIntervalSince1970, 0)) &+ UInt64(report.done))
                .fill(ink.ink)
                .frame(height: 38)
                .padding(.horizontal, 24)
            Text("Thank you for showing up")
                .font(small)
                .foregroundStyle(ink.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Words

    private func statusWord(_ status: DayStatus) -> String {
        switch status {
        case .done: return "Done"
        case .open: return "To do"
        case .missed: return "Missed"
        case .flexible, .resting: return "Off"
        }
    }

    private func detailLine(_ item: DailyReport.Item) -> String? {
        var parts: [String] = []
        if let detail = item.detail { parts.append(detail) }
        if options.showStreaks, item.streak > 0 {
            parts.append("Streak \(item.streak) \(item.streakUnit)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The picked Apple Health numbers Health has for the day, as line
    /// items: a line reading "n/a" would look like a misprint.
    private var healthLines: [(label: String, value: String)] {
        let health = report.health
        var lines: [(label: String, value: String)] = []
        if options.shows(.steps), let steps = health.steps {
            lines.append(("Steps", ReportFormat.count(steps)))
        }
        if options.shows(.exercise), let minutes = health.exerciseMinutes {
            lines.append(("Exercise", ReportFormat.duration(minutes: minutes)))
            for kind in health.exerciseKinds {
                lines.append(("  \(kind.name)", ReportFormat.duration(minutes: kind.minutes)))
            }
        }
        if options.shows(.sleep), let hours = health.sleepHours {
            lines.append(("Sleep", ReportFormat.duration(minutes: hours * 60)))
        }
        if options.shows(.mindful), let minutes = health.mindfulMinutes {
            lines.append(("Mindful", ReportFormat.duration(minutes: minutes)))
        }
        if options.shows(.calories) {
            if let eaten = health.eatenKcal { lines.append(("Eaten", ReportFormat.kcal(eaten))) }
            if let burned = health.burnedKcal { lines.append(("Burned", ReportFormat.kcal(burned))) }
            if let net = health.netKcal { lines.append((net <= 0 ? "Deficit" : "Surplus", ReportFormat.signedKcal(net))) }
        }
        if options.shows(.macros) {
            if let protein = health.protein { lines.append(("Protein", ReportFormat.grams(protein))) }
            if let carbs = health.carbs { lines.append(("Carbs", ReportFormat.grams(carbs))) }
            if let fat = health.fat { lines.append(("Fat", ReportFormat.grams(fat))) }
        }
        return lines
    }
}

// MARK: - Shapes

/// A slip torn along its top and bottom: a rectangle with saw teeth for
/// those edges. The Layout picker's sketch wears it too.
struct ReceiptSlip: Shape {
    static let depth: CGFloat = 5
    var tooth: CGFloat = 10
    var depth: CGFloat = Self.depth

    func path(in rect: CGRect) -> Path {
        let count = max(Int((rect.width / tooth).rounded()), 1)
        let step = rect.width / CGFloat(count)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + depth))
        for index in 0..<count {
            let x = rect.minX + step * CGFloat(index)
            path.addLine(to: CGPoint(x: x + step / 2, y: rect.minY))
            path.addLine(to: CGPoint(x: x + step, y: rect.minY + depth))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth))
        for index in 0..<count {
            let x = rect.maxX - step * CGFloat(index)
            path.addLine(to: CGPoint(x: x - step / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: x - step, y: rect.maxY - depth))
        }
        path.closeSubpath()
        return path
    }
}

/// A straight line across the middle of its frame, for rules and leaders.
private struct Leader: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// Bars and gaps of one to four points from a seed, so a day always prints
/// the same code. Decoration only; it encodes nothing.
private struct Barcode: Shape {
    let seed: UInt64

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var state = seed | 1
        var x = rect.minX
        var isBar = true
        while x < rect.maxX {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let width = min(CGFloat(1 + (state >> 62)), rect.maxX - x)
            if isBar { path.addRect(CGRect(x: x, y: rect.minY, width: width, height: rect.height)) }
            x += width
            isBar.toggle()
        }
        return path
    }
}
