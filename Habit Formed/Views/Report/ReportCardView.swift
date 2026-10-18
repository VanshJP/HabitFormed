import SwiftUI

// MARK: - Report Card

/// The shareable card for one day: who and when, the day's count in the
/// header's corner, every included habit, and whatever extras are switched
/// on. Rendered to an image with `ImageRenderer`, so it uses painted fills
/// only (no glass).
///
/// Fixed at `width` points with Dynamic Type pinned, so the card looks the
/// same on every phone it is forwarded to. The layouts that are things of
/// their own (`ReportLayout.ownsLook`) are the whole image instead: the front
/// page, the punch card, the night sky and the envelope edge to edge, and
/// the receipt, a slip lying on the card's ground.
struct ReportCardView: View {
    let report: DailyReport
    let options: ReportOptions

    static let width: CGFloat = 390
    static let receiptWidth: CGFloat = 340
    /// Rows listed before "+N more", so a long list keeps the card a sensible
    /// height in a chat.
    static let maxItems = 12

    private var palette: ReportPalette { ReportPalette(options: options) }

    /// What the card lies on when it is sent: its own ground, or the colour
    /// under a layout with paper of its own.
    static func backdrop(for options: ReportOptions) -> ReportBackdrop {
        switch options.layout {
        case .frontPage: return .color(AppColors.newsprint)
        case .punchCard, .stamps: return .color(AppColors.table)
        case .constellation: return .color(AppColors.nightSky)
        default: return ReportBackdrop(options: options)
        }
    }

    var body: some View {
        Group {
            switch options.layout {
            case .receipt:
                ReportReceipt(report: report, options: options)
                    .frame(width: Self.receiptWidth)
                    .reportRegion(.habits, outlined: false)
                    .padding(.vertical, 28)
                    .frame(width: Self.width)
                    .reportCanvas(look: options.look, paper: palette.paper)
            case .frontPage:
                ReportFrontPage(report: report, options: options)
                    .reportRegion(.habits, outlined: false)
            case .punchCard:
                ReportPunchCard(report: report, options: options)
                    .reportRegion(.habits, outlined: false)
            case .constellation:
                ReportConstellation(report: report, options: options)
                    .reportRegion(.habits, outlined: false)
            case .stamps:
                ReportStamps(report: report, options: options)
                    .reportRegion(.habits, outlined: false)
            default:
                card
            }
        }
        .reportInk(palette)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
                .reportRegion(.header)
            habits
                .reportRegion(.habits)
            if ReportHealthSection.shows(health: report.health, options: options) {
                ReportHealthSection(health: report.health, options: options, palette: palette)
                    .reportRegion(.health)
            }
            if !options.trimmedNote.isEmpty {
                ReportNote(text: options.trimmedNote, palette: palette)
                    .reportRegion(.note)
            }
        }
        .reportCardFrame(options: options, palette: palette)
    }

    /// The layout's habits.
    @ViewBuilder
    private var habits: some View {
        switch options.layout {
        case .list:
            habitList
        case .grid:
            ReportHabitGrid(items: report.items, palette: palette, showStreaks: options.showStreaks)
        case .focus:
            ReportFocus(report: report, palette: palette, numerals: options.font.numerals)
        case .orbit:
            ReportOrbit(report: report, palette: palette, showStreaks: options.showStreaks, numerals: options.font.numerals)
        case .week:
            ReportWeekBoard(report: report, palette: palette, showStreaks: options.showStreaks)
        case .rings:
            ReportRings(report: report, palette: palette, showStreaks: options.showStreaks, numerals: options.font.numerals)
        case .sundial:
            ReportSundial(report: report, options: options, palette: palette)
        case .garden:
            ReportGarden(report: report, palette: palette, showStreaks: options.showStreaks)
        case .bubbles:
            ReportBubbles(items: report.items, palette: palette, showStreaks: options.showStreaks)
        case .ledger:
            ReportLedger(report: report, options: options, palette: palette)
        case .timeline:
            ReportTimeline(report: report, options: options, palette: palette)
        case .minimal:
            ReportMinimal(report: report, options: options, palette: palette)
        case .frontPage, .punchCard, .constellation, .stamps, .receipt:
            // Drawn whole in `body`.
            EmptyView()
        }
    }

    // MARK: - Header

    /// Centred over a poster's ring (Focus, Orbit), so that card reads as
    /// one; otherwise the day's count sits at the trailing edge.
    private var header: some View {
        ReportCardHeader(
            title: report.name.isEmpty ? "Daily report" : report.name,
            subtitle: report.date.formatted(.dateTime.weekday(.wide).month(.wide).day()),
            badge: report.isPerfect ? "Perfect day" : nil,
            palette: palette,
            centred: options.layout.isPoster
        ) {
            if options.layout.showsRing { count }
        }
    }

    /// The day's count as a ring (an arc per habit, `ReportDayRing`) or as
    /// a number.
    @ViewBuilder
    private var count: some View {
        switch options.ring {
        case .big:
            ring(size: 84, lineWidth: 9, numeral: 22)
        case .corner:
            ring(size: 56, lineWidth: 6, numeral: 15)
        case .off:
            Text(report.countText)
                .font(.system(size: 32, weight: .bold, design: options.font.numerals).monospacedDigit())
                .foregroundStyle(palette.ink)
                .lineLimit(1)
        }
    }

    private func ring(size: CGFloat, lineWidth: CGFloat, numeral: CGFloat) -> some View {
        ReportDayRing(report: report, palette: palette, diameter: size, lineWidth: lineWidth) {
            Text(report.countText)
                .font(.system(size: numeral, weight: .bold, design: options.font.numerals).monospacedDigit())
                .foregroundStyle(palette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, lineWidth + 2)
        }
    }

    // MARK: - List

    private var habitList: some View {
        let shown = Array(report.items.prefix(Self.maxItems))
        let hidden = report.items.count - shown.count

        return VStack(alignment: .leading, spacing: 0) {
            if shown.isEmpty {
                Text("No habits on this card")
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                if let line = detailLine(item) {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                if options.showNotes, let note = item.note {
                    Text("“\(note)”")
                        .font(.caption.italic())
                        .foregroundStyle(palette.ink.opacity(0.8))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if options.showWeek {
                // The six days before; today is the mark beside them.
                HStack(spacing: 3) {
                    ForEach(Array(item.week.dropLast().enumerated()), id: \.offset) { _, logged in
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

    /// Done is the habit's colour; open is a dashed ring; missed a quiet
    /// empty ring (a card sent to friends is no place for red crosses); a
    /// flexible weekly day is a dash.
    private func statusMark(_ status: DayStatus, tint: Color) -> some View {
        Group {
            switch status {
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(tint)
            case .open:
                Image(systemName: "circle.dashed").foregroundStyle(palette.faint)
            case .missed:
                Image(systemName: "circle").foregroundStyle(palette.faint)
            case .flexible, .resting:
                Image(systemName: "minus.circle").foregroundStyle(palette.faint)
            }
        }
        .font(.system(size: 20, weight: .semibold))
    }
}

// MARK: - Previews

#if DEBUG
extension DailyReport {
    /// A filled-in report for previews.
    static var sample: DailyReport {
        func item(_ title: String, _ symbol: String, _ hex: String, _ status: DayStatus, _ detail: String?, _ streak: Int, note: String? = nil, at hour: Int? = nil) -> Item {
            Item(
                id: UUID(), title: title, symbol: symbol, colorHex: hex, status: status,
                detail: detail, streak: streak, streakUnit: streak == 1 ? "day" : "days", note: note,
                week: [true, true, false, true, true, true, status == .done],
                loggedAt: hour.flatMap { Calendar.current.date(bySettingHour: $0, minute: 10, second: 0, of: Date()) }
            )
        }
        return DailyReport(
            date: Date(),
            isToday: true,
            name: "Vansh",
            items: [
                item("Read", "book.fill", "#5966A6", .done, nil, 12, note: "Finished chapter 4", at: 7),
                item("Practice piano", "pianokeys", "#8C5C84", .done, "30 min", 5, at: 13),
                item("10k steps", "figure.walk", "#2BA8A8", .done, "11.2k of 10k steps", 3, at: 18),
                item("Meditate", "brain.head.profile", "#739F80", .open, "10 min", 0),
                item("Workout", "dumbbell.fill", "#BF7866", .flexible, "2/4 this week", 2),
            ],
            done: 3,
            expected: 4,
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

#Preview("Layouts") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(ReportLayout.gallery) { layout in
                ReportCardView(
                    report: .sample,
                    options: ReportOptions(layout: layout, metrics: Set(ReportMetric.allCases), note: "Rest day tomorrow.")
                )
            }
        }
        .padding()
    }
    .background(Color.black)
}
#endif
