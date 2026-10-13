import SwiftUI

// MARK: - Paper tones

private enum Paper {
    static let sheet = Color(red: 0.984, green: 0.980, blue: 0.965)
    static let ink = AppColors.inkOnLight
    static let faint = Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.55)
    static let rule = Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.25)
}

// MARK: - Receipt

/// A till receipt on the template's canvas: each habit a line item, the day's
/// total at the bottom, calories as the tax line, and a barcode for the day.
struct ReceiptCard: View {
    let report: DailyReport
    let content: ReportContent

    private let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
    private let monoBold = Font.system(size: 13, weight: .bold, design: .monospaced)

    var body: some View {
        receipt
            .padding(.horizontal, 30)
            .padding(.vertical, 30)
            .frame(width: ReportCardView.width)
            .background {
                CanvasLookView(look: content.theme.look, mood: .session, tone: .primary)
            }
    }

    private var receipt: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(expand(content.title).uppercased())
                    .font(.system(size: 19, weight: .heavy, design: .monospaced))
                    .multilineTextAlignment(.center)
                Text("DAILY HABIT RECEIPT")
                    .font(mono)
                Text(report.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year()))
                    .font(mono)
                if !report.name.isEmpty {
                    Text("CUSTOMER: \(report.name.uppercased())")
                        .font(mono)
                }
            }
            .frame(maxWidth: .infinity)

            DashedRule()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(report.items.prefix(12)) { item in
                    lineItem(item)
                }
                if report.items.isEmpty {
                    Text("NO ITEMS")
                        .font(mono)
                        .frame(maxWidth: .infinity)
                }
            }

            DashedRule()

            VStack(spacing: 4) {
                row("HABITS DONE", "\(report.done)/\(report.expected)")
                if content.showPerfectStreak {
                    row("STREAK BONUS", "x\(report.perfectStreak)")
                }
                if content.showCalories {
                    row("CALORIES IN", plain(report.health.eatenKcal))
                    row("CALORIES OUT", plain(report.health.burnedKcal))
                    if let net = report.health.netKcal {
                        row("NET", (net > 0 ? "+" : "") + Int(net.rounded()).formatted())
                    }
                    if content.calorieGoal > 0 {
                        row("BUDGET", Int(content.calorieGoal.rounded()).formatted())
                    }
                }
            }

            DashedRule()

            HStack {
                Text("TOTAL")
                Spacer()
                Text(report.percentText)
            }
            .font(.system(size: 20, weight: .heavy, design: .monospaced))

            let message = expand(content.message)
            if !message.isEmpty {
                Text(message.uppercased())
                    .font(mono)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }

            Barcode(seed: barcodeSeed)
                .frame(height: 44)
                .padding(.horizontal, 12)
                .padding(.top, 6)

            let footer = expand(content.footer)
            if !footer.isEmpty {
                Text(footer.uppercased())
                    .font(mono)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            Text("HABIT FORMED")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Paper.faint)
        }
        .foregroundStyle(Paper.ink)
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .background {
            ZigzagPaper()
                .fill(Paper.sheet)
                .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
        }
    }

    private func lineItem(_ item: DailyReport.Item) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("1 \(item.title.uppercased())")
                    .font(item.isDone ? monoBold : mono)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(price(for: item.status))
                    .font(monoBold)
            }
            if let detail = detailLine(item) {
                Text("  \(detail.uppercased())")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Paper.faint)
                    .lineLimit(2)
            }
        }
        .opacity(item.status == .missed ? 0.6 : 1)
    }

    private func detailLine(_ item: DailyReport.Item) -> String? {
        var parts: [String] = []
        if let detail = item.detail { parts.append(detail) }
        if content.showStreaks, item.streak > 1 { parts.append("\(item.streak) \(item.streakUnit)") }
        if content.showNotes, let note = item.note { parts.append(note) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func price(for status: DayStatus) -> String {
        switch status {
        case .done: return "PAID"
        case .open: return "DUE"
        case .missed: return "VOID"
        case .flexible, .resting: return "HOLD"
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
        }
        .font(mono)
    }

    private func plain(_ kcal: Double?) -> String {
        guard let kcal else { return "N/A" }
        return Int(kcal.rounded()).formatted()
    }

    private func expand(_ text: String) -> String {
        ReportText.expand(text, report: report, content: content)
    }

    /// Stable per day and per person, so the same day prints the same code.
    private var barcodeSeed: UInt64 {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: report.date) ?? 1
        let name = report.name.unicodeScalars.reduce(UInt64(7)) { ($0 &* 31) &+ UInt64($1.value) }
        return UInt64(day) &* 2_654_435_761 &+ name &+ UInt64(report.done * 97 + report.expected)
    }
}

/// A rectangle with a torn zigzag along its top and bottom edges.
private struct ZigzagPaper: Shape {
    var tooth: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let count = max(Int(rect.width / tooth), 2)
        let step = rect.width / CGFloat(count)
        let depth = tooth * 0.5

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + depth))
        for i in 0..<count {
            let x = rect.minX + CGFloat(i) * step
            path.addLine(to: CGPoint(x: x + step / 2, y: rect.minY))
            path.addLine(to: CGPoint(x: x + step, y: rect.minY + depth))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth))
        for i in 0..<count {
            let x = rect.maxX - CGFloat(i) * step
            path.addLine(to: CGPoint(x: x - step / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: x - step, y: rect.maxY - depth))
        }
        path.closeSubpath()
        return path
    }
}

/// A dashed hairline, the receipt's section break.
private struct DashedRule: View {
    var body: some View {
        DashLine()
            .stroke(Paper.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .frame(height: 1)
    }

    private struct DashLine: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

/// Decorative bars from a seeded generator. Not a scannable code.
private struct Barcode: View {
    let seed: UInt64

    var body: some View {
        Canvas { context, size in
            var state = seed | 1
            var x: CGFloat = 0
            var dark = true
            while x < size.width {
                // xorshift64: cheap and deterministic.
                state ^= state << 13
                state ^= state >> 7
                state ^= state << 17
                let width = CGFloat(1 + state % 3)
                if dark {
                    context.fill(
                        Path(CGRect(x: x, y: 0, width: width, height: size.height)),
                        with: .color(Paper.ink)
                    )
                }
                x += width
                dark.toggle()
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Clean

/// White paper and ink: a serif title, the count, and the list.
struct CleanCard: View {
    let report: DailyReport
    let content: ReportContent

    private var accent: Color { Color(hex: content.accentHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    let title = expand(content.title)
                    if !title.isEmpty {
                        Text(title)
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(Paper.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(byline)
                        .font(.subheadline)
                        .foregroundStyle(Paper.faint)
                }
                Spacer(minLength: 8)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(report.done)/\(report.expected)")
                        .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Paper.ink)
                    Text("habits done")
                        .font(.headline)
                        .foregroundStyle(Paper.faint)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Paper.ink.opacity(0.08))
                        Capsule()
                            .fill(accent)
                            .frame(width: report.fraction > 0 ? max(6, proxy.size.width * report.fraction) : 0)
                    }
                }
                .frame(height: 6)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(report.items.prefix(ReportCardView.maxItems).enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Rectangle().fill(Paper.ink.opacity(0.08)).frame(height: 0.5)
                    }
                    row(item)
                }
                if report.items.count > ReportCardView.maxItems {
                    Text("+\(report.items.count - ReportCardView.maxItems) more")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Paper.faint)
                        .padding(.top, 8)
                }
            }

            if content.showCalories, report.health.eatenKcal != nil || report.health.burnedKcal != nil {
                Text("\(ReportFormat.kcal(report.health.eatenKcal)) eaten · \(ReportFormat.kcal(report.health.burnedKcal)) burned · \(ReportFormat.signedKcal(report.health.netKcal)) net")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Paper.faint)
            }

            let message = expand(content.message)
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 17, weight: .regular, design: .serif).italic())
                    .foregroundStyle(Paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                let footer = expand(content.footer)
                if !footer.isEmpty {
                    Text(footer)
                        .font(.caption)
                        .foregroundStyle(Paper.faint)
                }
                Spacer(minLength: 8)
                HabitFormedMark(tint: accent, ink: Paper.faint)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
        .frame(width: ReportCardView.width, alignment: .leading)
        .background(Paper.sheet)
        .environment(\.colorScheme, .light)
    }

    private var byline: String {
        let date = report.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return report.name.isEmpty ? date : "\(report.name) · \(date)"
    }

    private func row(_ item: DailyReport.Item) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: mark(item.status))
                .font(.body.weight(.semibold))
                .foregroundStyle(item.isDone ? accent : Paper.faint)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Paper.ink.opacity(item.isDone ? 1 : 0.6))
                let detail = detailLine(item)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Paper.faint)
                }
                if content.showNotes, let note = item.note {
                    Text(note)
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundStyle(Paper.ink.opacity(0.75))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    private func detailLine(_ item: DailyReport.Item) -> String {
        var parts: [String] = []
        if let detail = item.detail { parts.append(detail) }
        if content.showStreaks, item.streak > 1 { parts.append("\(item.streak) \(item.streakUnit)") }
        return parts.joined(separator: " · ")
    }

    private func mark(_ status: DayStatus) -> String {
        switch status {
        case .done: return "checkmark.circle.fill"
        case .open: return "circle"
        case .missed: return "xmark.circle"
        case .flexible, .resting: return "minus.circle"
        }
    }

    private func expand(_ text: String) -> String {
        ReportText.expand(text, report: report, content: content)
    }
}
