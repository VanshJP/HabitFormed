import SwiftUI

/// One habit as a compact row for Today's Rows layout: glyph, name and status
/// line, with the way to log at the trailing end (the slide, a timer, a
/// health reading, or a past day's toggle). Same gestures as a tile: tap
/// opens the habit, slide logs, long press opens the shared menu. Done (logged
/// on the day shown) fills the row with the habit's color, from the knob when
/// it is slid, and turns its glyph and marks white.
struct HabitRowView: View {
    let habit: Habit
    /// The day the list is showing. Equals today in normal use.
    var selectedDate: Date = .now
    /// True when the list is showing a day before today.
    var isPastDay: Bool = false
    /// Logged on the day shown, the same fact a tile fills for (see
    /// `HabitTileView.isDone`).
    let isDone: Bool
    let actions: HabitActions

    @Environment(HealthKitService.self) private var health
    @Environment(TimerCenter.self) private var timerCenter
    @Environment(DayTracker.self) private var dayTracker

    /// Wide enough for "Slide to log" beside the knob.
    private let trailingWidth: CGFloat = 136

    /// How full the row is, 0...1. The knob drives it while it slides; a
    /// log or an undo made anywhere else plays it to 1 or 0.
    @State private var fill: CGFloat = 0
    /// While the knob is held the long-press menu stays empty, so pausing
    /// mid-slide never opens it.
    @State private var isSliding = false

    var body: some View {
        // Re-render at midnight so today-driven state updates.
        let _ = dayTracker.today

        return HStack(spacing: 12) {
            IconChip(icon: habit.symbol, tint: isDone ? .white : habit.color, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HabitStatusLine(habit: habit, selectedDate: selectedDate, isPastDay: isPastDay, isOnFill: isDone)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
                .frame(width: trailingWidth)
        }
        .padding(.leading, AppLayout.tilePadding)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .opacity(habit.restingDaysLeft == nil || isPastDay ? 1 : 0.6)
        .completionFill(habit.color, amount: $fill)
        .glassCard(
            cornerRadius: AppLayout.tileRadius,
            tint: isDone ? AppColors.featuredTint(habit.color) : AppColors.identityTint(habit.color)
        )
        .contentShape(.rect(cornerRadius: AppLayout.tileRadius))
        .onTapGesture { Haptics.light(); actions.open() }
        .contextMenu {
            if !isSliding {
                HabitContextMenu(habit: habit, selectedDate: selectedDate, isPastDay: isPastDay, actions: actions, timerCenter: timerCenter)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(habit.title), \(isDone ? "done" : "not done")")
        .accessibilityHint("Opens history. Long press for options.")
        .onAppear { syncFill(fillState, animation: nil) }
        .onChange(of: fillState) { old, new in
            // A log or an undo plays; moving to another day just shows it.
            syncFill(new, animation: old.day == new.day ? AppMotion.settle : nil)
        }
    }

    // MARK: - Fill

    private var fillState: CompletionFill.Key {
        CompletionFill.Key(day: selectedDate.startOfDay, done: isDone)
    }

    private func syncFill(_ state: CompletionFill.Key, animation: Animation?) {
        withMotion(animation) { fill = state.done ? 1 : 0 }
    }

    // MARK: - Trailing

    @ViewBuilder
    private var trailing: some View {
        if isPastDay {
            pastDayToggle
        } else {
            switch habit.trackKind {
            case .health: healthReading
            case .timer: RowTimerButton(habit: habit, onStart: actions.startTimer)
            case .manual:
                if let days = habit.restingDaysLeft {
                    Text(days == 1 ? "Next log tomorrow" : "Next log in \(days) days")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: SlideToLogTrack.trackHeight)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                } else {
                    SlideToLogTrack(accent: habit.color, isLogged: isDone, progress: $fill, isSliding: $isSliding) {
                        actions.log()
                    }
                }
            }
        }
    }

    private var pastDayToggle: some View {
        let logged = isDone
        return Button(action: actions.togglePastDay) {
            Label(logged ? "Logged" : "Log", systemImage: logged ? "checkmark.circle.fill" : "plus.circle")
                .font(.caption.weight(.semibold))
                .symbolSwap(logged)
                .foregroundStyle(logged ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .frame(maxWidth: .infinity, minHeight: SlideToLogTrack.trackHeight)
                .background(Capsule().fill(Color.white.opacity(logged ? 0.18 : 0.08)))
                .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(logged ? "Logged on \(selectedDate.relativeDayName)" : "Log \(selectedDate.relativeDayName)")
    }

    /// Today's reading against the target, with a thin meter under it.
    private var healthReading: some View {
        let isWeekly = habit.frequency == .weekly
        let value = (isWeekly
            ? health.liveWeeklyValues[habit.source.rawValue]
            : health.liveValues[habit.source.rawValue]) ?? 0
        let progress = min(value / max(habit.targetValue, 1), 1.0)

        return VStack(alignment: .trailing, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(habit.source.compactValue(value))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: value))
                    .motion(AppMotion.snap, value: value)
                Text("of \(habit.source.compactValue(habit.targetValue))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            MeterBar(fraction: progress, color: isDone ? .white : habit.color.glyphTone, height: 4)
                .motion(AppMotion.settle, value: progress)
        }
        .frame(minHeight: SlideToLogTrack.trackHeight)
    }
}
