import SwiftUI

/// One habit on the Today grid: its glyph, name and one status line, over a
/// bottom row that depends on how it is tracked. Done is the tile filled with
/// the habit's color; a slide fills it from the knob as it moves.
/// - Manual: the slide-to-log track
/// - HealthKit: today's reading against the target, with a meter
/// - Timer: the week's dots and a play capsule
///
/// Gestures: tap opens the detail sheet, the slide logs today, a long press
/// opens the context menu. On a past day the bottom row is a pill that
/// toggles that day's log, so a forgotten day is one tap to fix.
struct HabitTileView: View {
    let habit: Habit
    /// The day the grid is showing. Equals today in normal use.
    var selectedDate: Date = .now
    /// True when the grid is showing a day before today.
    var isPastDay: Bool = false
    let actions: HabitActions

    @Environment(HealthKitService.self) private var health
    @Environment(TimerCenter.self) private var timerCenter
    @Environment(DayTracker.self) private var dayTracker

    /// The slide knob's place, 0...1. Manual habits on today fill from it.
    @State private var slide: CGFloat = 0
    /// While the knob is held the long-press menu stays empty, so pausing
    /// mid-slide never opens it.
    @State private var isSliding = false
    /// The fill for everything without a slide: health, timers, past days.
    @State private var doneFill: CGFloat = 0
    @State private var showStopConfirm = false

    private let padding = AppLayout.tilePadding

    /// Completion for the day being shown; a weekly habit counts the whole
    /// week once logged. Fills follow it, except a manual habit on today,
    /// which fills from its slide (logged today or not).
    private var effectiveCompleted: Bool {
        if habit.frequency == .weekly {
            return !habit.completionsInWeek(of: selectedDate).isEmpty
        }
        return habit.isCompleted(on: selectedDate)
    }

    var body: some View {
        // Re-render at midnight so today-driven state updates.
        let _ = dayTracker.today

        return content
            // A resting interval habit recedes so it reads as "sitting out
            // today" yet stays discoverable.
            .opacity(intervalRestingDays == nil || isPastDay ? 1 : 0.6)
            .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
            .completionFill(habit.color, amount: fillsFromSlide ? $slide : $doneFill)
            .glassCard(
                cornerRadius: AppLayout.tileRadius,
                tint: effectiveCompleted ? AppColors.featuredTint(habit.color) : AppColors.identityTint(habit.color)
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

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow
            Spacer(minLength: 12)
            Text(habit.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            HabitStatusLine(habit: habit, selectedDate: selectedDate, isPastDay: isPastDay)
                .padding(.top, 3)
            Spacer(minLength: 12)
            bottomSection
        }
        .padding(padding)
    }

    // MARK: - Fill

    /// True when the slide is the bottom row, so the fill follows the knob.
    private var fillsFromSlide: Bool {
        !isPastDay && habit.trackKind == .manual && intervalRestingDays == nil
    }

    private var isFilled: Bool {
        fillsFromSlide ? habit.isCompletedToday : effectiveCompleted
    }

    private var fillState: CompletionFill.Key {
        CompletionFill.Key(day: selectedDate.startOfDay, done: effectiveCompleted, doneToday: habit.isCompletedToday)
    }

    private func syncFill(_ state: CompletionFill.Key, animation: Animation?) {
        withAnimation(animation) {
            slide = state.doneToday ? 1 : 0
            doneFill = state.done ? 1 : 0
        }
    }

    // MARK: - Header

    private var topRow: some View {
        HStack(alignment: .top) {
            IconChip(icon: habit.symbol, tint: isFilled ? .white : habit.color, size: 30)
            Spacer()
            statusBadge
        }
    }

    /// Only where the bottom row cannot say "done" itself: a health meter
    /// reads as progress, not completion.
    @ViewBuilder
    private var statusBadge: some View {
        if effectiveCompleted && habit.trackKind == .health && !isPastDay {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(.white)
        }
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
        let logged = habit.isCompleted(on: selectedDate)
        return Button(action: actions.togglePastDay) {
            HStack(spacing: 6) {
                Image(systemName: logged ? "checkmark.circle.fill" : "plus.circle")
                    .font(.footnote.weight(.semibold))
                Text(logged ? "Logged" : "Tap to log")
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
                Text("of \(habit.source.compactValue(habit.targetValue))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if isWeekly {
                    Text("Week")
                        .eyebrowStyle()
                }
            }
            MeterBar(fraction: progress, color: habit.color.glyphTone, height: 6)
                .motion(AppMotion.settle, value: progress)
        }
        .frame(minHeight: SlideToLogTrack.trackHeight, alignment: .bottom)
    }

    /// The week's dots on the leading side, the play capsule on the trailing.
    private var timerRow: some View {
        HStack(spacing: 0) {
            WeekDotsView(completionDates: habit.completionDates, accent: habit.color)
            Spacer(minLength: 6)
            Button {
                Haptics.medium()
                actions.startTimer()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: timerIcon)
                        .font(.caption2.weight(.bold))
                    Text(timerLabel)
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(minHeight: 32)
                .background(
                    Capsule().fill(habit.isCompletedToday ? habit.color.opacity(0.3) : habit.color.opacity(0.85))
                )
                .frame(minHeight: SlideToLogTrack.trackHeight)
                .contentShape(.rect)
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
        return "\(habit.timerDurationSeconds / 60)m"
    }

    /// Manual: the slide track, swapped for a resting pill while an interval
    /// countdown runs so an early cycle does not invite a log.
    @ViewBuilder
    private var manualSlide: some View {
        if let remaining = intervalRestingDays {
            intervalRestingPill(days: remaining)
        } else {
            SlideToLogTrack(accent: habit.color, isLogged: habit.isCompletedToday, progress: $slide, isSliding: $isSliding) {
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
        let state = effectiveCompleted ? "done" : "not done"
        return "\(habit.title), \(state), \(habit.displayStreak) \(habit.streakUnitLabel) streak"
    }
}
