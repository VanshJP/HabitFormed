import SwiftUI

/// The shareable card for one week: perfect days against the week before,
/// each habit's seven days as squares, and the headlines. Same rules as the
/// daily card: a fixed width, Dynamic Type pinned and painted fills only, so
/// `ImageRenderer` can draw it and it looks the same wherever it is sent.
struct WeeklyRecapCardView: View {
    let recap: WeeklyRecap
    /// The daily card's look: theme, accent and type (layout is the daily
    /// card's own).
    let options: ReportOptions

    static let width: CGFloat = ReportCardView.width
    /// Rows drawn before "+N more".
    static let maxRows = 12

    private var palette: ReportPalette { ReportPalette(look: options.look, accentHex: options.accentHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            hero
            WeeklyRecapGrid(recap: recap, palette: palette, maxRows: Self.maxRows)
            headlines
            HabitFormedMark(tint: palette.accent, ink: palette.faint)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(width: Self.width, alignment: .leading)
        .background { background }
        .fontDesign(options.font.design)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, palette.isLight ? .light : .dark)
    }

    @ViewBuilder
    private var background: some View {
        if let look = options.look {
            CanvasLookView(look: look, mood: .session)
        } else {
            palette.paper
        }
    }

    // MARK: - Header and hero

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(recap.name.isEmpty ? "Weekly recap" : recap.name)
                .font(.title3.bold())
                .foregroundStyle(palette.ink)
            Text(recap.rangeText)
                .font(.subheadline)
                .foregroundStyle(palette.secondary)
        }
    }

    private var hero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(recap.perfectDays)")
                .font(.system(size: 64, weight: .bold, design: options.font.numerals).monospacedDigit())
                .foregroundStyle(recap.perfectDays > 0 ? AppColors.success : palette.ink)
            VStack(alignment: .leading, spacing: 3) {
                Text(recap.perfectDays == 1 ? "perfect day" : "perfect days")
                    .font(.title3.bold())
                    .foregroundStyle(palette.ink)
                Text("out of 7, \(recap.trendText)")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
            }
        }
    }

    // MARK: - Headlines

    private var headlines: some View {
        HStack(alignment: .top, spacing: 12) {
            headline("Logged", "\(recap.logged) of \(recap.expected)")
            if let longest = recap.longestStreak {
                headline("Longest", "\(longest.title), \(longest.value)")
            }
            if let climber = recap.climber {
                headline("Climber", "\(climber.title) \(climber.value)")
            }
        }
    }

    private func headline(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .eyebrowStyle(palette.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: options.font.numerals).monospacedDigit())
                .foregroundStyle(palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
