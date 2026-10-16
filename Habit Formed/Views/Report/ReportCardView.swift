import SwiftUI

// MARK: - Report Card

/// The shareable card for one day: who and when, how much got done, every
/// included habit, and whatever extras are switched on. Rendered to an image
/// with `ImageRenderer`, so it uses painted fills only (no glass).
///
/// Fixed at `width` points with Dynamic Type pinned, so the card looks the
/// same on every phone it is forwarded to. The receipt is the exception: it
/// is the slip alone at `receiptWidth`, with nothing behind it, so the image
/// sent is just the receipt.
struct ReportCardView: View {
    let report: DailyReport
    let options: ReportOptions

    static let width: CGFloat = 390
    static let receiptWidth: CGFloat = 340

    /// The drawn width for a layout, for the renderer and the preview.
    static func width(for layout: ReportLayout) -> CGFloat {
        layout == .receipt ? receiptWidth : width
    }
    /// Rows listed before "+N more", so a long list keeps the card a sensible
    /// height in a chat.
    static let maxItems = 12

    private var palette: ReportPalette { ReportPalette(look: options.look, accentHex: options.accentHex) }

    var body: some View {
        Group {
            if options.layout == .receipt {
                // The slip is the whole image: its own header, Health lines,
                // note and mark, and no card or canvas behind it.
                ReportReceipt(report: report, options: options)
                    .frame(width: Self.receiptWidth)
            } else {
                card
            }
        }
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, palette.isLight ? .light : .dark)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            habits
            ReportHealthSection(health: report.health, options: options, palette: palette)
            note
            HabitFormedMark(tint: palette.accent, ink: palette.faint)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(width: Self.width, alignment: .leading)
        .background { background }
        .fontDesign(options.font.design)
    }

    @ViewBuilder
    private var background: some View {
        if let look = options.look {
            CanvasLookView(look: look, mood: .session)
        } else {
            palette.paper
        }
    }

    /// The layout's habits, under the hero ring where the layout has one.
    @ViewBuilder
    private var habits: some View {
        switch options.layout {
        case .list:
            hero
            habitList
        case .grid:
            hero
            ReportHabitGrid(items: report.items, palette: palette, showStreaks: options.showStreaks)
        case .focus:
            ReportFocus(report: report, palette: palette, showStreaks: options.showStreaks, numerals: options.font.numerals)
        case .orbit:
            ReportOrbit(report: report, palette: palette, showStreaks: options.showStreaks, numerals: options.font.numerals)
        case .week:
            hero
            ReportWeekBoard(report: report, palette: palette, showStreaks: options.showStreaks)
        case .rings:
            hero
            ReportRings(report: report, palette: palette, showStreaks: options.showStreaks, numerals: options.font.numerals)
        case .bubbles:
            hero
            ReportBubbles(items: report.items, palette: palette, showStreaks: options.showStreaks)
        case .receipt:
            EmptyView()
        }
    }

    // MARK: - Header and hero

    /// Centred over a poster's ring (Focus, Orbit), so that card reads as
    /// one. With the ring set to the corner, it sits small at the header's
    /// trailing edge.
    private var header: some View {
        let centred = options.layout.isPoster
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: centred ? .center : .leading, spacing: 2) {
                Text(report.name.isEmpty ? "Daily report" : report.name)
                    .font(.title3.bold())
                    .foregroundStyle(palette.ink)
                Text(report.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
            }
            .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
            if options.layout.showsRing, options.ring == .corner {
                ring(size: 54, lineWidth: 6, numeral: 15)
            }
        }
    }

    /// The day's count in its ring, an arc per habit (`ReportDayRing`).
    private func ring(size: CGFloat, lineWidth: CGFloat, numeral: CGFloat) -> some View {
        ReportDayRing(report: report, palette: palette, diameter: size, lineWidth: lineWidth) {
            Text("\(report.done)/\(report.expected)")
                .font(.system(size: numeral, weight: .bold, design: options.font.numerals).monospacedDigit())
                .foregroundStyle(palette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, lineWidth + 2)
        }
    }

    /// The verdict, the day's share and the perfect-day streak, beside the
    /// big ring when it is on.
    private var hero: some View {
        HStack(alignment: .center, spacing: 18) {
            if options.layout.showsRing, options.ring == .big {
                ring(size: 100, lineWidth: 10, numeral: 26)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(report.verdict)
                    .font(.title2.bold())
                    .foregroundStyle(palette.ink)
                Text("\(report.percentText) of the day")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
                if options.showStreaks, report.perfectStreak > 0 {
                    HStack(spacing: 6) {
                        StreakFlameGlyph(heat: .of(streak: report.perfectStreak, doneToday: report.isPerfect))
                            .frame(height: 15)
                        Text(report.perfectStreak == 1 ? "1 perfect day" : "\(report.perfectStreak) perfect days in a row")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.ink.opacity(0.85))
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Habits

    private var habitList: some View {
        let shown = Array(report.items.prefix(Self.maxItems))
        let hidden = report.items.count - shown.count

        return VStack(alignment: .leading, spacing: 0) {
            if shown.isEmpty {
                Text("No habits on this card.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
                    .padding(.vertical, 12)
            }
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(palette.rule)
                        .frame(height: 0.5)
                        .padding(.leading, 34)
                }
                row(item)
            }
            if hidden > 0 {
                Text("+\(hidden) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondary)
                    .padding(.vertical, 8)
                    .padding(.leading, 34)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(palette.well, in: .rect(cornerRadius: AppLayout.tileRadius, style: .continuous))
    }

    private func row(_ item: DailyReport.Item) -> some View {
        let tint = palette.habitTint(item.colorHex)

        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: item.symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink.opacity(item.isDone ? 1 : 0.65))
                    .lineLimit(1)
                if let line = detailLine(item) {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                }
                if options.showNotes, let note = item.note {
                    Text("“\(note)”")
                        .font(.caption.italic())
                        .foregroundStyle(palette.ink.opacity(0.8))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 6)

            if options.showWeek {
                HStack(spacing: 3) {
                    ForEach(Array(item.week.enumerated()), id: \.offset) { _, logged in
                        Circle()
                            .fill(logged ? tint : palette.rule)
                            .frame(width: 5, height: 5)
                    }
                }
            }

            statusMark(item.status, tint: tint)
        }
        .padding(.vertical, 9)
    }

    private func detailLine(_ item: DailyReport.Item) -> String? {
        var parts: [String] = []
        if let detail = item.detail { parts.append(detail) }
        if options.showStreaks, item.streak > 0 {
            parts.append("\(item.streak) \(item.streakUnit)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Done is the habit's colour; open is a dashed ring; missed is a quiet
    /// cross; a flexible weekly day is a dash.
    private func statusMark(_ status: DayStatus, tint: Color) -> some View {
        Group {
            switch status {
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(tint)
            case .open:
                Image(systemName: "circle.dashed").foregroundStyle(palette.faint)
            case .missed:
                Image(systemName: "xmark.circle").foregroundStyle(AppColors.error.opacity(0.85))
            case .flexible, .resting:
                Image(systemName: "minus.circle").foregroundStyle(palette.faint)
            }
        }
        .font(.system(size: 20, weight: .semibold))
    }

    // MARK: - Note

    @ViewBuilder
    private var note: some View {
        let text = options.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(palette.accent)
                    .frame(width: 3)
                Text(text)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(palette.ink.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Palette

/// Ink, wells and accents for a theme: white on the canvases, near-black on
/// paper. The accent is the look's own unless a palette colour is picked.
struct ReportPalette {
    let isLight: Bool
    let accent: Color

    /// `look` is the card's canvas, or nil for paper.
    init(look: CanvasLook?, accentHex: String = "") {
        isLight = look == nil
        if !accentHex.isEmpty {
            let picked = Color(hex: accentHex)
            accent = isLight ? picked : picked.glyphTone
        } else {
            accent = look?.accent ?? AppColors.primary
        }
    }

    var paper: Color { Color(red: 0.984, green: 0.980, blue: 0.965) }
    var ink: Color { isLight ? AppColors.inkOnLight : .white }
    var secondary: Color { ink.opacity(isLight ? 0.6 : 0.55) }
    var faint: Color { ink.opacity(isLight ? 0.4 : 0.45) }
    var well: Color { isLight ? AppColors.inkOnLight.opacity(0.05) : Color.white.opacity(0.07) }
    var rule: Color { isLight ? AppColors.inkOnLight.opacity(0.12) : Color.white.opacity(0.12) }

    /// A habit's colour, lifted on dark canvases and kept deep on paper so it
    /// clears contrast either way.
    func habitTint(_ hex: String) -> Color {
        dataTint(Color(hex: hex))
    }

    /// Any data colour (a macro, a habit) toned for the card's ground.
    func dataTint(_ color: Color) -> Color {
        isLight ? color : color.glyphTone
    }
}

// MARK: - Font

extension ReportFont {
    var design: Font.Design {
        switch self {
        case .standard: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .mono: return .monospaced
        }
    }

    /// Big numbers stay rounded on the default face, as they always were.
    var numerals: Font.Design { self == .standard ? .rounded : design }
}

// MARK: - Mark

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

// MARK: - Previews

#if DEBUG
extension DailyReport {
    /// A filled-in report for previews.
    static var sample: DailyReport {
        func item(_ title: String, _ symbol: String, _ hex: String, _ status: DayStatus, _ detail: String?, _ streak: Int, note: String? = nil) -> Item {
            Item(
                id: UUID(), title: title, symbol: symbol, colorHex: hex, status: status,
                detail: detail, streak: streak, streakUnit: streak == 1 ? "day" : "days", note: note,
                week: [true, true, false, true, true, true, status == .done]
            )
        }
        return DailyReport(
            date: Date(),
            isToday: true,
            name: "Vansh",
            items: [
                item("Read", "book.fill", "#5966A6", .done, nil, 12, note: "Finished chapter 4"),
                item("Practice piano", "pianokeys", "#8C5C84", .done, "30 min", 5),
                item("10k steps", "figure.walk", "#2BA8A8", .done, "11.2k of 10k steps", 3),
                item("Meditate", "brain.head.profile", "#739F80", .open, "10 min", 0),
                item("Workout", "dumbbell.fill", "#BF7866", .flexible, "2/4 this week", 2),
            ],
            done: 3,
            expected: 4,
            perfectStreak: 4,
            health: DayHealthMetrics(
                steps: 11_240, activeKcal: 610, restingKcal: 1_790, eatenKcal: 1_850,
                exerciseMinutes: 42, sleepHours: 7 + 40.0 / 60, mindfulMinutes: nil,
                protein: 142, carbs: 180, fat: 61,
                exerciseKinds: [
                    ExerciseKind(name: "Strength", minutes: 26),
                    ExerciseKind(name: "Walk", minutes: 9),
                    ExerciseKind(name: "Other", minutes: 7, isOther: true),
                ]
            )
        )
    }
}

#Preview("Themes") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(ReportTheme.allCases) { theme in
                ReportCardView(
                    report: .sample,
                    options: ReportOptions(theme: theme, metrics: Set(ReportMetric.allCases), note: "Rest day tomorrow.")
                )
            }
        }
        .padding()
    }
    .background(Color.black)
}
#endif
