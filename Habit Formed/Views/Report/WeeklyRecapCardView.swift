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

    private var palette: ReportPalette { ReportPalette(options: options) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ReportCardHeader(
                title: recap.name.isEmpty ? "Weekly recap" : recap.name,
                subtitle: recap.rangeText,
                palette: palette
            )
            .reportRegion(.header)
            VStack(alignment: .leading, spacing: 18) {
                hero
                WeeklyRecapGrid(recap: recap, palette: palette, maxRows: Self.maxRows)
            }
            .reportRegion(.habits)
            headlines
            if !options.trimmedNote.isEmpty {
                ReportNote(text: options.trimmedNote, palette: palette)
                    .reportRegion(.note)
            }
        }
        .reportCardFrame(options: options, palette: palette)
        .reportInk(palette)
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(recap.perfectDays)")
                .font(.system(size: 64, weight: .bold, design: options.font.numerals).monospacedDigit())
                .foregroundStyle(recap.perfectDays > 0 ? palette.success : palette.ink)
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

    /// Each number first, then what it belongs to, so a long habit name
    /// shrinks on its own line instead of cutting the number off.
    private var headlines: some View {
        HStack(alignment: .top, spacing: 12) {
            headline("Logged", "\(recap.logged) of \(recap.expected)", nil)
            if let longest = recap.longestStreak {
                headline("Longest run", longest.value, longest.title)
            }
            if let climber = recap.climber {
                headline("Climbed most", "\(climber.value) logs", climber.title)
            }
        }
    }

    private func headline(_ label: String, _ value: String, _ habit: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .eyebrowStyle(palette.secondary)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: options.font.numerals).monospacedDigit())
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let habit {
                Text(habit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
