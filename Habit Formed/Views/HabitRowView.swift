import SwiftUI

/// One habit as a compact row for Today's Rows layout: glyph, name and status
/// line, with the way to log at the trailing end (the slide, a timer, a
/// health reading, or a past day's toggle). Same gestures as a tile: tap
/// opens the habit, slide logs, long press opens the shared menu.
struct HabitRowView: View {
    let habit: Habit
    /// The day the list is showing. Equals today in normal use.
    var selectedDate: Date = .now
    /// True when the list is showing a day before today.
    var isPastDay: Bool = false
    let actions: HabitActions

    @Environment(HealthKitService.self) private var health
    @Environment(TimerCenter.self) private var timerCenter
    @Environment(DayTracker.self) private var dayTracker

    /// Wide enough for "Slide to log" beside the knob.
    private let trailingWidth: CGFloat = 136

    private var isDone: Bool {
        if habit.frequency == .weekly {
            return !habit.completionsInWeek(of: selectedDate).isEmpty
        }
        return habit.isCompleted(on: selectedDate)
    }

    var body: some View {
        // Re-render at midnight so today-driven state updates.
        let _ = dayTracker.today

        return HStack(spacing: 12) {
            IconChip(icon: habit.symbol, tint: habit.color, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HabitStatusLine(habit: habit, selectedDate: selectedDate, isPastDay: isPastDay)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
                .frame(width: trailingWidth)
        }
        .padding(.leading, AppLayout.tilePadding)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .opacity(habit.restingDaysLeft == nil || isPastDay ? 1 : 0.6)
        .glassCard(
            cornerRadius: AppLayout.tileRadius,
            tint: isDone ? AppColors.featuredTint(habit.color) : AppColors.identityTint(habit.color)
        )
        .contentShape(.rect(cornerRadius: AppLayout.tileRadius))
        .onTapGesture { Haptics.light(); actions.open() }
        .contextMenu {
            HabitContextMenu(habit: habit, selectedDate: selectedDate, isPastDay: isPastDay, actions: actions, timerCenter: timerCenter)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(habit.title), \(isDone ? "done" : "not done")")
        .accessibilityHint("Opens history. Long press for options.")
    }

    // MARK: - Trailing

    @ViewBuilder
    private var trailing: some View {
        if isPastDay {
            pastDayToggle
        } else {
            switch habit.trackKind {
            case .health: healthReading
            case .timer: timerButton
            case .manual:
                if let days = habit.restingDaysLeft {
                    Text(days == 1 ? "Next tomorrow" : "Next in \(days) days")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: SlideToLogTrack.trackHeight)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                } else {
                    SlideToLogTrack(accent: habit.color, isLogged: habit.isCompletedToday) {
                        actions.log()
                    }
                }
            }
        }
    }

    private var pastDayToggle: some View {
        let logged = habit.isCompleted(on: selectedDate)
        return Button(action: actions.togglePastDay) {
            Label(logged ? "Logged" : "Log", systemImage: logged ? "checkmark.circle.fill" : "plus.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(logged ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .frame(maxWidth: .infinity, minHeight: SlideToLogTrack.trackHeight)
                .background(Capsule().fill(logged ? habit.color.opacity(0.28) : Color.white.opacity(0.08)))
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
                Text("of \(habit.source.compactValue(habit.targetValue))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            MeterBar(fraction: progress, color: habit.color.glyphTone, height: 4)
                .motion(AppMotion.settle, value: progress)
        }
        .frame(minHeight: SlideToLogTrack.trackHeight)
    }

    private var timerButton: some View {
        let done = habit.isCompletedToday
        let active = timerCenter.habitID == habit.id
        return Button {
            Haptics.medium()
            actions.startTimer()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: done ? "checkmark" : (active && timerCenter.isRunning ? "waveform" : "play.fill"))
                    .font(.caption2.weight(.bold))
                Text(done ? "Done" : (active ? timerText : "\(habit.timerDurationSeconds / 60) min"))
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: SlideToLogTrack.trackHeight)
            .background(Capsule().fill(done ? habit.color.opacity(0.3) : habit.color.opacity(0.85)))
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle())
        .disabled(done)
        .accessibilityLabel(active ? "Open timer" : "Start \(habit.timerDurationSeconds / 60) minute timer")
    }

    private var timerText: String {
        let s = timerCenter.remainingSeconds
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
