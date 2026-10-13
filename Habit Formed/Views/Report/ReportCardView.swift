import SwiftUI

// MARK: - Report Card

/// The shareable card for one day, drawn in the template's style. Rendered to
/// an image with `ImageRenderer`, so it uses painted fills only: Liquid Glass
/// and materials do not survive the renderer.
///
/// Fixed at `width` points with Dynamic Type pinned, so a card looks the same
/// on every phone it is forwarded to.
struct ReportCardView: View {
    let report: DailyReport
    let content: ReportContent

    static let width: CGFloat = 390
    /// Rows listed before "+N more", so a long habit list keeps the card a
    /// sensible height in a chat.
    static let maxItems = 10

    var body: some View {
        Group {
            switch content.style {
            case .scoreboard: ScoreboardCard(report: report, content: content)
            case .fuel: FuelCard(report: report, content: content)
            case .checkIn: CheckInCard(report: report, content: content)
            case .streak: StreakCard(report: report, content: content)
            case .receipt: ReceiptCard(report: report, content: content)
            case .clean: CleanCard(report: report, content: content)
            }
        }
        .frame(width: Self.width)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Shared: canvas

/// The dark styles' poster: the template's canvas at full intensity with the
/// content inset over it.
struct DarkCardFrame<Content: View>: View {
    let content: ReportContent
    let inner: Content

    init(content: ReportContent, @ViewBuilder _ inner: () -> Content) {
        self.content = content
        self.inner = inner()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            inner
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(width: ReportCardView.width, alignment: .leading)
        .background {
            CanvasLookView(look: content.theme.look, mood: .session, tone: .primary)
        }
    }
}

// MARK: - Shared: header and footer

/// Whose day, which day, and the app's mark. The name matters most: a card
/// forwarded twice still says whose report it is.
struct ReportHeader: View {
    let report: DailyReport
    let accent: Color

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(report.name.isEmpty ? "Daily report" : report.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(report.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 8)
            HabitFormedMark(tint: accent, ink: .white.opacity(0.7))
        }
    }
}

/// The app's small wordmark: a hexagon grid glyph and the name.
struct HabitFormedMark: View {
    var tint: Color
    var ink: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text("Habit Formed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ink)
        }
    }
}

/// The template's closing line, if it has one.
struct ReportFooter: View {
    let text: String
    var ink: Color = .white.opacity(0.45)

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }
}

/// The template's message as a quoted line.
struct ReportMessage: View {
    let text: String
    let accent: Color

    var body: some View {
        if !text.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(accent)
                    .frame(width: 3)
                Text(text)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Shared: items

/// One habit on a dark card: glyph, name, its detail and note, the week's
/// dots if asked for, and a done / open / missed mark.
struct ReportItemRow: View {
    let item: DailyReport.Item
    let content: ReportContent

    private var tint: Color { Color(hex: item.colorHex) }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: item.symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(tint.glyphTone)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(item.isDone ? 1 : 0.7))
                    .lineLimit(1)
                if let line = detailLine {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                if content.showNotes, let note = item.note {
                    Text("“\(note)”")
                        .font(.caption.italic())
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 6)

            if content.showWeek {
                ReportWeekDots(days: item.week, tint: tint)
            }

            ReportStatusMark(status: item.status, tint: tint)
        }
        .padding(.vertical, 9)
    }

    private var detailLine: String? {
        var parts: [String] = []
        if let detail = item.detail { parts.append(detail) }
        if content.showStreaks, item.streak > 0 {
            parts.append("\(item.streak) \(item.streakUnit)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Done is the habit's colour, filled; open is a dashed ring; missed is a
/// quiet cross; a flexible weekly day is a dash.
struct ReportStatusMark: View {
    let status: DayStatus
    let tint: Color
    var size: CGFloat = 20

    var body: some View {
        Group {
            switch status {
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(tint.glyphTone)
            case .open:
                Image(systemName: "circle.dashed")
                    .foregroundStyle(.white.opacity(0.45))
            case .missed:
                Image(systemName: "xmark.circle")
                    .foregroundStyle(AppColors.error.opacity(0.85))
            case .flexible, .resting:
                Image(systemName: "minus.circle")
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .font(.system(size: size, weight: .semibold))
    }
}

/// Seven small dots, oldest first.
struct ReportWeekDots: View {
    let days: [Bool]
    let tint: Color
    var empty: Color = .white.opacity(0.18)

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, logged in
                Circle()
                    .fill(logged ? tint.glyphTone : empty)
                    .frame(width: 5, height: 5)
            }
        }
    }
}

/// The listed habits on one painted panel, with "+N more" past the cap.
struct ReportItemList: View {
    let report: DailyReport
    let content: ReportContent

    var body: some View {
        let shown = Array(report.items.prefix(ReportCardView.maxItems))
        let hidden = report.items.count - shown.count

        VStack(alignment: .leading, spacing: 0) {
            if shown.isEmpty {
                Text(content.showUnfinished ? "No habits for this day." : "Nothing logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.vertical, 10)
            }
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 0.5)
                        .padding(.leading, 34)
                }
                ReportItemRow(item: item, content: content)
            }
            if hidden > 0 {
                Text("+\(hidden) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 8)
                    .padding(.leading, 34)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Shared: health

/// Activity numbers as small chips, only the ones Health had.
struct ReportActivityChips: View {
    let health: DayHealthMetrics

    private struct Chip: Identifiable {
        let icon: String
        let text: String
        var id: String { icon }
    }

    private var chips: [Chip] {
        var list: [Chip] = []
        if let steps = health.steps { list.append(Chip(icon: "figure.walk", text: "\(ReportFormat.count(steps)) steps")) }
        if let exercise = health.exerciseMinutes { list.append(Chip(icon: "figure.run", text: ReportFormat.minutes(exercise))) }
        if let sleep = health.sleepHours { list.append(Chip(icon: "bed.double.fill", text: "\(ReportFormat.hours(sleep)) sleep")) }
        if let mindful = health.mindfulMinutes { list.append(Chip(icon: "brain.head.profile", text: "\(ReportFormat.minutes(mindful)) mindful")) }
        return list
    }

    var body: some View {
        if !chips.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(chips) { chip in
                    HStack(spacing: 5) {
                        Image(systemName: chip.icon)
                            .font(.caption2.weight(.semibold))
                        Text(chip.text)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
        }
    }
}

/// Eaten, burned and net in one line of three numbers.
struct ReportCalorieStrip: View {
    let health: DayHealthMetrics
    let goal: Double
    let accent: Color

    var body: some View {
        HStack(spacing: 0) {
            column("Eaten", ReportFormat.kcal(health.eatenKcal))
            divider
            column("Burned", ReportFormat.kcal(health.burnedKcal))
            divider
            column(netLabel, ReportFormat.signedKcal(health.netKcal), tint: netTint)
        }
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous)
                .fill(Color.white.opacity(0.07))
        }
    }

    private var netLabel: String {
        guard let net = health.netKcal else { return "Net" }
        return net <= 0 ? "Deficit" : "Surplus"
    }

    private var netTint: Color {
        guard let net = health.netKcal else { return .white }
        return net <= 0 ? AppColors.success : AppColors.warning
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 0.5, height: 30)
    }

    private func column(_ label: String, _ value: String, tint: Color = .white) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .eyebrowStyle(Color.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#if DEBUG
extension DailyReport {
    /// A filled-in report for previews.
    static var sample: DailyReport {
        func item(_ title: String, _ symbol: String, _ hex: String, _ status: DayStatus, _ detail: String?, _ streak: Int, note: String? = nil) -> Item {
            Item(
                id: UUID(), title: title, symbol: symbol, colorHex: hex, kind: .manual, status: status,
                detail: detail, streak: streak, streakUnit: streak == 1 ? "day" : "days", note: note,
                week: [true, true, false, true, true, true, status == .done]
            )
        }
        let items = [
            item("Read", "book.fill", "#5966A6", .done, nil, 12, note: "Finished chapter 4"),
            item("Practice piano", "pianokeys", "#8C5C84", .done, "30 min", 5),
            item("10k steps", "figure.walk", "#2BA8A8", .done, "11.2k of 10k steps", 3),
            item("Meditate", "brain.head.profile", "#739F80", .open, "10 min", 0),
            item("Workout", "dumbbell.fill", "#BF7866", .flexible, "2/4 this week", 2),
        ]
        let week = (0..<7).map { offset in
            DaySummary(date: Date().adding(days: offset - 6), done: offset == 3 ? 2 : 4, expected: 4)
        }
        return DailyReport(
            date: Date(), isToday: true, name: "Vansh", items: items, allItems: items,
            done: 3, expected: 4, perfectStreak: 4, bestStreak: 9, week: week,
            health: DayHealthMetrics(
                steps: 11_240, activeKcal: 610, restingKcal: 1_790, eatenKcal: 1_850,
                exerciseMinutes: 42, sleepHours: 7.4, mindfulMinutes: nil,
                protein: 128, carbs: 190, fat: 62
            )
        )
    }
}

#Preview("All styles") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(ReportPreset.all) { preset in
                let template = ReportTemplate.make(from: preset, sortOrder: 0)
                ReportCardView(report: .sample, content: template.content)
            }
        }
        .padding()
    }
    .background(Color.black)
}
#endif
