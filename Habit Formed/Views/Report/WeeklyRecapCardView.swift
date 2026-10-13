import SwiftUI

/// The shareable card for one week: perfect days against the week before,
/// each habit's seven days as squares, and the headlines. Same rules as the
/// daily card: a fixed width, Dynamic Type pinned and painted fills only, so
/// `ImageRenderer` can draw it and it looks the same wherever it is sent.
struct WeeklyRecapCardView: View {
    let recap: WeeklyRecap
    let theme: ReportTheme

    static let width: CGFloat = ReportCardView.width
    /// Rows drawn before "+N more".
    static let maxRows = 12

    private let cell: CGFloat = 24
    private let cellSpacing: CGFloat = 6

    private var palette: ReportPalette { ReportPalette(theme: theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            hero
            grid
            headlines
            HabitFormedMark(tint: palette.accent, ink: palette.faint)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(width: Self.width, alignment: .leading)
        .background { background }
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, palette.isLight ? .light : .dark)
    }

    @ViewBuilder
    private var background: some View {
        if let look = theme.look {
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
                .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
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

    // MARK: - Grid

    private var grid: some View {
        let shown = Array(recap.rows.prefix(Self.maxRows))
        let hidden = recap.rows.count - shown.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                HStack(spacing: cellSpacing) {
                    ForEach(recap.days) { day in
                        VStack(spacing: 3) {
                            Circle()
                                .fill(day.isPerfect ? AppColors.success : Color.clear)
                                .frame(width: 5, height: 5)
                            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(palette.secondary)
                        }
                        .frame(width: cell)
                    }
                }
            }

            if shown.isEmpty {
                Text("No habits on this card.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
            }

            ForEach(shown) { row in
                HStack(spacing: 8) {
                    Text(row.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: cellSpacing) {
                        ForEach(Array(row.days.enumerated()), id: \.offset) { _, status in
                            square(status, hex: row.colorHex)
                        }
                    }
                }
            }

            if hidden > 0 {
                Text("+\(hidden) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondary)
            }
        }
        .padding(14)
        .background(palette.well, in: .rect(cornerRadius: AppLayout.tileRadius, style: .continuous))
    }

    /// Filled in the habit's colour when logged, a faint square when missed,
    /// an outline for today still open, a ghost on a weekly habit's free day,
    /// and nothing on a day it sat out.
    private func square(_ status: DayStatus, hex: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        let fill: Color = switch status {
        case .done: palette.habitTint(hex)
        case .missed: palette.rule
        case .flexible: palette.rule.opacity(0.4)
        case .open, .resting: .clear
        }
        return shape
            .fill(fill)
            .overlay {
                if status == .open {
                    shape.strokeBorder(palette.secondary, lineWidth: 1.5)
                }
            }
            .frame(width: cell, height: cell)
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
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
