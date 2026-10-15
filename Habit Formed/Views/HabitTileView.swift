import SwiftUI

/// One habit on the Today grid: its glyph as faded art in the top corner,
/// then its name and a status line led by the streak's number, over a
/// bottom row that depends on how it is tracked. Done (logged on the day
/// shown) is the tile filled with the habit's color, its glyph and marks
/// turning white; a slide fills it from the knob as it moves.
/// - Manual: the slide-to-log track
/// - HealthKit: today's reading against the target, with a meter
/// - Timer: a play pill shaped like the slide
///
/// Gestures: tap opens the habit's page, the slide logs today, a long press
/// opens the context menu. On a past day the bottom row is a pill that
/// toggles that day's log, so a forgotten day is one tap to fix.
struct HabitTileView: View {
    let habit: Habit
    /// The day the grid is showing. Equals today in normal use.
    var selectedDate: Date = .now
    /// True when the grid is showing a day before today.
    var isPastDay: Bool = false
    /// Logged on the day shown, the ledger's `.done`, handed down from the
    /// page's tracks so a tile never scans its logs: the fill, the white
    /// glyph, the featured tint and the spoken state all follow it, so a
    /// tile agrees with the week strip's ring and its own pill.
    /// A weekly habit's week is the status line's to say.
    let isDone: Bool
    let actions: HabitActions

    @Environment(HealthKitService.self) private var health
    @Environment(TimerCenter.self) private var timerCenter
    @Environment(DayTracker.self) private var dayTracker

    /// How full the tile is, 0...1. The knob drives it while it slides; a
    /// log or an undo made anywhere else plays it to 1 or 0.
    @State private var fill: CGFloat = 0
    /// While the knob is held the long-press menu stays empty, so pausing
    /// mid-slide never opens it.
    @State private var isSliding = false
    @State private var showStopConfirm = false

    private let padding = AppLayout.tilePadding

    var body: some View {
        // Re-render at midnight so today-driven state updates.
        let _ = dayTracker.today

        return content
            .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
            .background(alignment: .topTrailing) { art }
            // A resting interval habit recedes so it reads as "sitting out
            // today" yet stays discoverable.
            .opacity(intervalRestingDays == nil || isPastDay ? 1 : 0.6)
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
            .confirmationDialog(
                "Stop the timer for \(habit.title)?",
                isPresented: $showStopConfirm,
                titleVisibility: .visible
            ) {
                Button("Stop", role: .destructive) {
                    Haptics.warning()
                    timerCenter.stop()
                }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("This session won't be logged.")
            }
            .onAppear { syncFill(fillState, animation: nil) }
            .onChange(of: fillState) { old, new in
                // A log or an undo plays; moving to another day just shows it.
                syncFill(new, animation: old.day == new.day ? AppMotion.settle : nil)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Opens history. Long press for options.")
    }

    // MARK: - Layout

    /// The words sit at the bottom over the way to log, leaving the top to
    /// the art. The status line is one numeral tall either way, so names
    /// line up across a row of tiles.
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 36)
            Text(habit.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            HabitStatusLine(habit: habit, selectedDate: selectedDate, isPastDay: isPastDay, isOnFill: isDone, prominent: true)
            bottomSection
                .padding(.top, 12)
        }
        .padding(padding)
    }

    /// The glyph drawn large and quiet in the top corner, behind the words,
    /// in the habit's own color rather than lifted toward white: the tile's
    /// art, the way SpeakUp's tool tiles wear theirs. White on the fill.
    private var art: some View {
        Image(systemName: habit.symbol)
            .font(.system(size: 38, weight: .medium))
            .foregroundStyle(isDone ? Color.white : habit.color)
            .opacity(isDone ? 0.35 : 0.55)
            .frame(width: 52, height: 52)
            .padding(padding)
            .accessibilityHidden(true)
    }

    // MARK: - Fill

    private var fillState: CompletionFill.Key {
        CompletionFill.Key(day: selectedDate.startOfDay, done: isDone)
    }

    private func syncFill(_ state: CompletionFill.Key, animation: Animation?) {
        withMotion(animation) { fill = state.done ? 1 : 0 }
    }

    // MARK: - Bottom section

    @ViewBuilder
    private var bottomSection: some View {
        if isPastDay {
            pastDayPill
        } else {
            switch habit.trackKind {
            case .health: healthProgressView
            case .timer: timerRow
            case .manual: manualSlide
            }
        }
    }

    /// A past day's log as a toggle: tap to add a forgotten log or remove a
    /// wrong one. The toast on Today offers the way back.
    private var pastDayPill: some View {
        let logged = isDone
        return Button(action: actions.togglePastDay) {
            HStack(spacing: 6) {
                Image(systemName: logged ? "checkmark.circle.fill" : "plus.circle")
                    .font(.footnote.weight(.semibold))
                    .symbolSwap(logged)
                Text(logged ? "Logged" : "Log")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(logged ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .frame(maxWidth: .infinity, minHeight: SlideToLogTrack.trackHeight)
            .background(
                Capsule().fill(Color.white.opacity(logged ? 0.18 : 0.08))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(logged ? "Logged on \(selectedDate.relativeDayName)" : "Log \(selectedDate.relativeDayName)")
    }

    /// Today's HealthKit reading against the target; weekly habits show the
    /// week-to-date sum.
    private var healthProgressView: some View {
        let isWeekly = habit.frequency == .weekly
        let liveValue = (isWeekly
            ? health.liveWeeklyValues[habit.source.rawValue]
            : health.liveValues[habit.source.rawValue]) ?? 0
        let progress = min(liveValue / max(habit.targetValue, 1), 1.0)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(habit.source.compactValue(liveValue))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: liveValue))
                    .motion(AppMotion.snap, value: liveValue)
                Text("of \(habit.source.compactValue(habit.targetValue))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if isWeekly {
                    Text("Week")
                        .eyebrowStyle()
                }
            }
            MeterBar(fraction: progress, color: isDone ? .white : habit.color.glyphTone, height: 6)
                .motion(AppMotion.settle, value: progress)
        }
        .frame(minHeight: SlideToLogTrack.trackHeight, alignment: .bottom)
    }

    /// Shaped like the slide it stands in for, so every tile's bottom row
    /// is one pill: the play glyph on a disc where the knob would sit, the
    /// length beside it. Tap anywhere on it to start.
    private var timerRow: some View {
        Button {
            Haptics.medium()
            actions.startTimer()
        } label: {
            HStack(spacing: 0) {
                Image(systemName: timerIcon)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative, isActive: timerIsActiveForThisHabit && timerCenter.isRunning)
                    .symbolSwap(timerIcon)
                    .frame(width: SlideToLogTrack.knobSize, height: SlideToLogTrack.knobSize)
                    .background(Circle().fill(habit.color.mix(with: .white, by: 0.22)).opacity(isDone ? 0 : 1))
                Text(timerLabel)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(isDone ? 1 : 0.7))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, SlideToLogTrack.knobSize * 0.4)
            }
            .padding(.horizontal, SlideToLogTrack.inset)
            .frame(maxWidth: .infinity, minHeight: SlideToLogTrack.trackHeight)
            .background(Capsule().fill(Color.white.opacity(isDone ? 0 : 0.08)))
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle())
        .disabled(habit.isCompletedToday)
        .accessibilityLabel(timerIsActiveForThisHabit ? "Open timer" : "Start \(habit.timerDurationSeconds / 60) minute timer")
        // Inside-out gesture priority: this absorbs the long press before
        // the tile's context menu can claim it.
        .onLongPressGesture(minimumDuration: 0.6) {
            guard timerIsActiveForThisHabit else { return }
            Haptics.light()
            showStopConfirm = true
        }
    }

    private var timerIsActiveForThisHabit: Bool { timerCenter.habitID == habit.id }

    private var timerIcon: String {
        if habit.isCompletedToday { return "checkmark" }
        if !timerIsActiveForThisHabit { return "play.fill" }
        return timerCenter.isRunning ? "waveform" : "pause.fill"
    }

    private var timerLabel: String {
        if habit.isCompletedToday { return "Done" }
        if timerIsActiveForThisHabit {
            let s = timerCenter.remainingSeconds
            return String(format: "%d:%02d", s / 60, s % 60)
        }
        return "\(habit.timerDurationSeconds / 60) min"
    }

    /// Manual: the slide track, swapped for a resting pill while an interval
    /// countdown runs so an early cycle does not invite a log.
    @ViewBuilder
    private var manualSlide: some View {
        if let remaining = intervalRestingDays {
            intervalRestingPill(days: remaining)
        } else {
            SlideToLogTrack(accent: habit.color, isLogged: isDone, progress: $fill, isSliding: $isSliding) {
                actions.log()
            }
        }
    }

    /// Days left on an interval countdown while the tile stays log-free; nil
    /// whenever the slide track belongs.
    private var intervalRestingDays: Int? { habit.restingDaysLeft }

    private func intervalRestingPill(days: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.footnote.weight(.semibold))
            Text(days == 1 ? "Next log tomorrow" : "Next log in \(days) days")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: SlideToLogTrack.trackHeight)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let state = isDone ? "done" : "not done"
        return "\(habit.title), \(state), \(habit.displayStreak) \(habit.streakUnitLabel) streak"
    }
}
