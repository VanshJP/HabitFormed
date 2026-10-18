import SwiftUI

/// The recap card's habit grid: weekday letters with a dot over each perfect
/// day, then one row of seven squares per habit.
struct WeeklyRecapGrid: View {
    let recap: WeeklyRecap
    let palette: ReportPalette
    let maxRows: Int

    /// Small enough that a name keeps about 20 characters beside its week.
    private let cell: CGFloat = 22
    private let cellSpacing: CGFloat = 4

    var body: some View {
        let shown = Array(recap.rows.prefix(maxRows))
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
                        .minimumScaleFactor(0.85)
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
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
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
}
