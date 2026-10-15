import SwiftUI

/// One line about a habit: the streak once there is one, and the schedule
/// fact that matters on the day shown ("2 of 5 this week", "Due today").
/// Shared by tiles and rows so both say the same thing.
///
/// The name above it leads; the streak sits back, a medium-weight number in
/// soft white and its unit softer still, the schedule in gray unless it asks
/// for attention, when it takes the habit's color. On the done fill they all
/// turn white at falling strengths.
struct HabitStatusLine: View {
    let habit: Habit
    let selectedDate: Date
    let isPastDay: Bool
    /// True on a surface filled with the habit's color.
    var isOnFill = false
    /// A tile sets the streak's number a step up from the line, still under
    /// the name's size; a row keeps it to the line's size.
    var prominent = false

    private var numberFont: Font {
        prominent
            ? .system(.callout, design: .rounded).weight(.medium).monospacedDigit()
            : .caption.weight(.semibold).monospacedDigit()
    }

    var body: some View {
        let streak = habit.displayStreak
        let cadence = cadenceStatus(streak: streak)
        let tone = isOnFill ? Color.white : habit.color.glyphTone

        ZStack(alignment: Alignment(horizontal: .leading, vertical: .lastTextBaseline)) {
            // One numeral tall either way, so a tile with no streak yet sits
            // level with its neighbour.
            if prominent {
                Text(verbatim: "0")
                    .font(numberFont)
                    .hidden()
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                if streak > 0 {
                    Text("\(streak)")
                        .font(numberFont)
                        .foregroundStyle(.white.opacity(isOnFill ? 0.95 : 0.75))
                        .contentTransition(.numericText(value: Double(streak)))
                    Text(habit.streakUnit(for: streak))
                        .foregroundStyle(.white.opacity(isOnFill ? 0.75 : 0.5))
                }
                if streak > 0, cadence != nil {
                    Text("·")
                        .foregroundStyle(isOnFill ? AnyShapeStyle(.white.opacity(0.5)) : AnyShapeStyle(.tertiary))
                }
                if let cadence {
                    Text(cadence.text)
                        .foregroundStyle(cadence.highlighted
                            ? AnyShapeStyle(tone)
                            : AnyShapeStyle(isOnFill ? .white.opacity(0.75) : .secondary))
                }
            }
            .font(.caption.weight(.medium).monospacedDigit())
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .motion(AppMotion.snap, value: streak)
    }

    /// The schedule fact, or nil when the streak says enough. Highlighted
    /// means it asks for attention (due) or celebrates (target met).
    private func cadenceStatus(streak: Int) -> (text: String, highlighted: Bool)? {
        switch habit.frequency {
        case .daily:
            return streak > 0 ? nil : ("Daily", false)
        case .weekly:
            let count = habit.completionsInWeek(of: selectedDate).count
            return ("\(count) of \(habit.weeklyTarget) this week", count >= habit.weeklyTarget)
        case .interval:
            let every = "Every \(habit.intervalDays) days"
            guard !isPastDay, habit.restingDaysLeft == nil, !habit.isCompletedToday else { return (every, false) }
            switch habit.daysUntilDue {
            case 0?: return ("Due today", true)
            case let d? where d < 0: return (d == -1 ? "1 day overdue" : "\(-d) days overdue", true)
            default: return (every, false)
            }
        }
    }
}
