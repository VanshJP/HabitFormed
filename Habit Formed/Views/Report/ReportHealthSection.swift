import SwiftUI

/// The card's Apple Health numbers, each only when picked
/// (`ReportOptions.metrics`) and only when Health has it for the day, in at
/// most two wells: activity (steps, exercise, sleep and mindful time, with
/// exercise split over the day's workouts when there were any), then food
/// (calories in and out over the macros and their split). Painted fills
/// only, like the rest of the card, so `ImageRenderer` draws it.
struct ReportHealthSection: View {
    let health: DayHealthMetrics
    let options: ReportOptions
    let palette: ReportPalette

    /// True when the section draws anything at all: a picked number Health
    /// has for the day. A well of blanks would read as a broken card.
    static func shows(health: DayHealthMetrics, options: ReportOptions) -> Bool {
        !activityStats(health, options).isEmpty
            || !calorieStats(health, options).isEmpty
            || !macroStats(health, options).isEmpty
    }

    private var wellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous)
    }

    var body: some View {
        let activity = Self.activityStats(health, options)
        let calories = Self.calorieStats(health, options)
        let macros = Self.macroStats(health, options)

        VStack(spacing: 12) {
            if !activity.isEmpty {
                activityWell(activity)
            }
            if !calories.isEmpty || !macros.isEmpty {
                foodWell(calories: calories, macros: macros)
            }
        }
    }

    // MARK: - Numbers

    /// One number in a well: its value over its label.
    private struct Stat {
        enum Tone { case plain, good, caution }

        let label: String
        let value: String
        var tone: Tone = .plain
        /// A colour's dot before the label, tying it to a split bar.
        var dot: Color? = nil
    }

    private static func activityStats(_ health: DayHealthMetrics, _ options: ReportOptions) -> [Stat] {
        var stats: [Stat] = []
        if options.shows(.steps), let steps = health.steps {
            stats.append(Stat(label: "Steps", value: ReportFormat.count(steps)))
        }
        if options.shows(.exercise), let minutes = health.exerciseMinutes {
            stats.append(Stat(label: "Exercise", value: ReportFormat.duration(minutes: minutes)))
        }
        if options.shows(.sleep), let hours = health.sleepHours {
            stats.append(Stat(label: "Sleep", value: ReportFormat.duration(minutes: hours * 60)))
        }
        if options.shows(.mindful), let minutes = health.mindfulMinutes {
            stats.append(Stat(label: "Mindful", value: ReportFormat.duration(minutes: minutes)))
        }
        return stats
    }

    private static func calorieStats(_ health: DayHealthMetrics, _ options: ReportOptions) -> [Stat] {
        guard options.shows(.calories) else { return [] }
        var stats: [Stat] = []
        if let eaten = health.eatenKcal {
            stats.append(Stat(label: "Eaten", value: ReportFormat.kcal(eaten)))
        }
        if let burned = health.burnedKcal {
            stats.append(Stat(label: "Burned", value: ReportFormat.kcal(burned)))
        }
        if let net = health.netKcal {
            stats.append(Stat(
                label: net <= 0 ? "Deficit" : "Surplus",
                value: ReportFormat.signedKcal(net),
                tone: net <= 0 ? .good : .caution
            ))
        }
        return stats
    }

    private static func macroStats(_ health: DayHealthMetrics, _ options: ReportOptions) -> [Stat] {
        guard options.shows(.macros) else { return [] }
        var stats: [Stat] = []
        if let protein = health.protein {
            stats.append(Stat(label: "Protein", value: ReportFormat.grams(protein), dot: AppColors.macroProtein))
        }
        if let carbs = health.carbs {
            stats.append(Stat(label: "Carbs", value: ReportFormat.grams(carbs), dot: AppColors.macroCarbs))
        }
        if let fat = health.fat {
            stats.append(Stat(label: "Fat", value: ReportFormat.grams(fat), dot: AppColors.macroFat))
        }
        return stats
    }

    // MARK: - Wells

    /// Up to four columns, then what the exercise went on when the day had
    /// a workout.
    private func activityWell(_ stats: [Stat]) -> some View {
        let kinds = options.shows(.exercise) && health.exerciseMinutes != nil ? health.exerciseKinds : []
        return VStack(spacing: 10) {
            columns(stats)
            if !kinds.isEmpty {
                exerciseSplit(kinds)
            }
        }
        .padding(.vertical, 12)
        .background(palette.well, in: wellShape)
    }

    /// Calories in and out over the macros, a hairline between them.
    private func foodWell(calories: [Stat], macros: [Stat]) -> some View {
        VStack(spacing: 12) {
            if !calories.isEmpty {
                columns(calories)
            }
            if !calories.isEmpty, !macros.isEmpty {
                Rectangle()
                    .fill(palette.rule)
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
            }
            if !macros.isEmpty {
                columns(macros)
                if let shares = health.macroShares {
                    MacroSplitBar(segments: [
                        (shares.protein, palette.dataTint(AppColors.macroProtein)),
                        (shares.carbs, palette.dataTint(AppColors.macroCarbs)),
                        (shares.fat, palette.dataTint(AppColors.macroFat)),
                    ])
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 12)
        .background(palette.well, in: wellShape)
    }

    // MARK: - Exercise

    /// Each kind of workout with its colour's dot and minutes ("Other" for
    /// minutes outside one), over a bar of the split, as the macros are drawn.
    private func exerciseSplit(_ kinds: [ExerciseKind]) -> some View {
        let total = max(kinds.reduce(0) { $0 + $1.minutes }, 1)
        return VStack(spacing: 8) {
            FlowLayout(spacing: 14, lineSpacing: 4, centred: true) {
                ForEach(kinds.indices, id: \.self) { index in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(palette.dataTint(kindColor(kinds, index)))
                            .frame(width: 6, height: 6)
                        Text(kinds[index].name)
                            .foregroundStyle(palette.secondary)
                        Text(ReportFormat.duration(minutes: kinds[index].minutes))
                            .foregroundStyle(palette.ink.opacity(0.85))
                    }
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            MacroSplitBar(segments: kinds.indices.map { index in
                (share: kinds[index].minutes / total, color: palette.dataTint(kindColor(kinds, index)))
            })
            .padding(.horizontal, 16)
        }
    }

    private func kindColor(_ kinds: [ExerciseKind], _ index: Int) -> Color {
        if kinds[index].isOther { return AppColors.accent }
        return AppColors.exerciseKinds[index % AppColors.exerciseKinds.count]
    }

    // MARK: - Columns

    private func columns(_ stats: [Stat]) -> some View {
        HStack(spacing: 0) {
            ForEach(stats.indices, id: \.self) { index in
                if index > 0 { columnRule }
                column(stats[index])
            }
        }
    }

    private var columnRule: some View {
        Rectangle().fill(palette.rule).frame(width: 0.5, height: 30)
    }

    private func column(_ stat: Stat) -> some View {
        VStack(spacing: 3) {
            Text(stat.value)
                .font(.system(size: 15, weight: .bold, design: options.font.numerals).monospacedDigit())
                .foregroundStyle(ink(for: stat.tone))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            HStack(spacing: 4) {
                if let dot = stat.dot {
                    Circle()
                        .fill(palette.dataTint(dot))
                        .frame(width: 6, height: 6)
                }
                Text(stat.label)
                    .eyebrowStyle(palette.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func ink(for tone: Stat.Tone) -> Color {
        switch tone {
        case .plain: return palette.ink
        case .good: return palette.success
        case .caution: return AppColors.warning
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
