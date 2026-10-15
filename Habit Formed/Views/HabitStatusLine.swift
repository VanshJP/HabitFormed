import SwiftUI

/// One quiet line about a habit: the streak once there is one, and the
/// cadence fact that matters on the day shown ("2 of 5 this week", "Due
/// today"). Shared by tiles and rows so both say the same thing.
struct HabitStatusLine: View {
    let habit: Habit
    let selectedDate: Date
    let isPastDay: Bool
    /// True on a surface filled with the habit's color, where a highlight
    /// turns white like the glyph instead of vanishing into the fill.
    var isOnFill = false

    var body: some View {
        let streak = habit.displayStreak
        let cadence = cadenceStatus

        HStack(spacing: 4) {
            if streak > 0 {
                Text("\(streak) \(habit.streakUnit(for: streak))")
                    .foregroundStyle(.white.opacity(0.9))
                    .layoutPriority(1)
            }
            if streak > 0, cadence != nil {
                Text("·")
                    .foregroundStyle(.tertiary)
            }
            if let cadence {
                Text(cadence.text)
                    .foregroundStyle(cadence.highlighted ? AnyShapeStyle(isOnFill ? .white : habit.color.glyphTone) : AnyShapeStyle(.secondary))
            }
        }
        .font(.caption.weight(.medium).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        // "3 days" rolls to "4 days" as the knob logs.
        .contentTransition(.numericText())
    }

    /// The schedule fact, or nil when the streak says enough. Highlighted
    /// means it asks for attention (due) or celebrates (target met).
    private var cadenceStatus: (text: String, highlighted: Bool)? {
        switch habit.frequency {
        case .daily:
            return habit.displayStreak > 0 ? nil : ("Daily", false)
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
