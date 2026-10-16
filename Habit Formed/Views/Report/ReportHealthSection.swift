import SwiftUI

/// The card's Apple Health numbers, each only when picked
/// (`ReportOptions.metrics`): calories in and out, the macros over their
/// split, exercise over what it went on (on a day with a workout), and a
/// line of chips for steps, exercise, sleep and mindful time.
/// Painted fills only, like the rest of the card, so `ImageRenderer` draws it.
struct ReportHealthSection: View {
    let health: DayHealthMetrics
    let options: ReportOptions
    let palette: ReportPalette

    private var wellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous)
    }

    var body: some View {
        // A group, so each part is its own child of the card's stack and one
        // left off takes no space.
        Group {
            if options.shows(.calories) { calories }
            if options.shows(.macros) { macros }
            if options.shows(.exercise), !health.exerciseKinds.isEmpty, let total = health.exerciseMinutes {
                exercise(total: total)
            }
            chipLine
        }
    }

    // MARK: - Calories

    private var calories: some View {
        let net = health.netKcal
        return HStack(spacing: 0) {
            column("Eaten", ReportFormat.kcal(health.eatenKcal))
            columnRule
            column("Burned", ReportFormat.kcal(health.burnedKcal))
            columnRule
            column(
                net.map { $0 <= 0 ? "Deficit" : "Surplus" } ?? "Net",
                ReportFormat.signedKcal(net),
                tint: net.map { $0 <= 0 ? AppColors.success : AppColors.warning }
            )
        }
        .padding(.vertical, 12)
        .background(palette.well, in: wellShape)
    }

    // MARK: - Macros

    /// Grams, each with its colour's dot, over a bar of how the energy splits.
    private var macros: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                column("Protein", ReportFormat.grams(health.protein), dot: AppColors.macroProtein)
                columnRule
                column("Carbs", ReportFormat.grams(health.carbs), dot: AppColors.macroCarbs)
                columnRule
                column("Fat", ReportFormat.grams(health.fat), dot: AppColors.macroFat)
            }
            if let shares = health.macroShares {
                MacroSplitBar(segments: [
                    (shares.protein, palette.dataTint(AppColors.macroProtein)),
                    (shares.carbs, palette.dataTint(AppColors.macroCarbs)),
                    (shares.fat, palette.dataTint(AppColors.macroFat)),
                ])
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(palette.well, in: wellShape)
    }

    // MARK: - Exercise

    /// The day's exercise minutes, then each kind of workout they went on
    /// with its colour ("Other" for minutes outside one) over a bar of the
    /// split, as the macros are drawn.
    private func exercise(total: Double) -> some View {
        let kinds = health.exerciseKinds
        return VStack(spacing: 12) {
            HStack(spacing: 5) {
                Image(systemName: ReportMetric.exercise.icon)
                    .font(.caption2.weight(.semibold))
                Text("\(ReportFormat.duration(minutes: total)) exercise")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(palette.ink.opacity(0.85))
            HStack(spacing: 0) {
                ForEach(kinds.indices, id: \.self) { index in
                    if index > 0 { columnRule }
                    column(kinds[index].name, ReportFormat.duration(minutes: kinds[index].minutes), dot: kindColor(kinds, index))
                }
            }
            MacroSplitBar(segments: kinds.indices.map { index in
                (share: kinds[index].minutes / max(total, 1), color: palette.dataTint(kindColor(kinds, index)))
            })
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(palette.well, in: wellShape)
    }

    private func kindColor(_ kinds: [ExerciseKind], _ index: Int) -> Color {
        if kinds[index].isOther { return AppColors.accent }
        return AppColors.exerciseKinds[index % AppColors.exerciseKinds.count]
    }

    // MARK: - Columns

    private var columnRule: some View {
        Rectangle().fill(palette.rule).frame(width: 0.5, height: 30)
    }

    private func column(_ label: String, _ value: String, tint: Color? = nil, dot: Color? = nil) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: options.font.numerals).monospacedDigit())
                .foregroundStyle(tint ?? palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 4) {
                if let dot {
                    Circle()
                        .fill(palette.dataTint(dot))
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .eyebrowStyle(palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chips

    private struct Chip: Identifiable {
        let icon: String
        let text: String
        var id: String { icon }
    }

    /// Only numbers Health has for the day: a chip with nothing in it would
    /// read as a broken card.
    private var metricChips: [Chip] {
        var chips: [Chip] = []
        if options.shows(.steps), let steps = health.steps {
            chips.append(Chip(icon: ReportMetric.steps.icon, text: "\(ReportFormat.count(steps)) steps"))
        }
        if options.shows(.exercise), health.exerciseKinds.isEmpty, let minutes = health.exerciseMinutes {
            chips.append(Chip(icon: ReportMetric.exercise.icon, text: "\(ReportFormat.duration(minutes: minutes)) exercise"))
        }
        if options.shows(.sleep), let hours = health.sleepHours {
            chips.append(Chip(icon: ReportMetric.sleep.icon, text: "\(ReportFormat.duration(minutes: hours * 60)) sleep"))
        }
        if options.shows(.mindful), let minutes = health.mindfulMinutes {
            chips.append(Chip(icon: ReportMetric.mindful.icon, text: "\(ReportFormat.duration(minutes: minutes)) mindful"))
        }
        return chips
    }

    @ViewBuilder
    private var chipLine: some View {
        let chips = metricChips
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
                    .foregroundStyle(palette.ink.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(palette.well, in: Capsule())
                }
            }
        }
    }
}

// MARK: - Split bar

/// One bar cut by share, a hair between the pieces. Pieces with no share are
/// left out, so a day of only protein is one solid bar.
private struct MacroSplitBar: View {
    let segments: [(share: Double, color: Color)]

    private let gap: CGFloat = 2

    var body: some View {
        let shown = segments.filter { $0.share > 0 }
        GeometryReader { proxy in
            let room = max(proxy.size.width - gap * CGFloat(max(shown.count - 1, 0)), 0)
            HStack(spacing: gap) {
                ForEach(shown.indices, id: \.self) { index in
                    Capsule()
                        .fill(shown[index].color)
                        .frame(width: room * shown[index].share)
                }
            }
        }
        .frame(height: 6)
    }
}
