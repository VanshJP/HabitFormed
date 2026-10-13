import SwiftUI

/// One habit on the Today grid: its glyph, name and one status line, over a
/// bottom row that depends on how it is tracked:
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
    let onTap: () -> Void
    let onLog: () -> Void
    let onUndoToday: () -> Void
    let onTogglePastDay: () -> Void
    let onEdit: () -> Void
    let onArrange: () -> Void
    let onRequestDelete: () -> Void
    let onStartTimer: () -> Void

    @Environment(HealthKitService.self) private var health
    @Environment(TimerCenter.self) private var timerCenter
    @Environment(DayTracker.self) private var dayTracker

    // Drives the radial reveal of `completionGlow`: 0 is empty, 1 bathes the
    // tile. Swept from the slide knob when the user logs by slide.
    @State private var sweepProgress: CGFloat = 0
    @State private var showStopConfirm = false

    private let padding = AppLayout.tilePadding

    /// Completion for the day being shown. Weekly habits stay lit for the
    /// whole week once logged, so the glow doesn't flicker between days.
    private var effectiveCompleted: Bool {
        if habit.frequency == .weekly {
            return !habit.completionsInWeek(of: selectedDate).isEmpty
        }
        return habit.isCompleted(on: selectedDate)
    }

    var body: some View {
        // Re-render at midnight so today-driven state updates.
        let _ = dayTracker.today

        return ZStack(alignment: .topLeading) {
            completionGlow
            content
                // A resting interval habit recedes so it reads as "sitting out
                // today" yet stays discoverable.
                .opacity(intervalRestingDays == nil || isPastDay ? 1 : 0.6)
        }
        .frame(minHeight: 168)
        .glassCard(
            cornerRadius: AppLayout.tileRadius,
            tint: effectiveCompleted ? AppColors.featuredTint(habit.color) : AppColors.identityTint(habit.color)
        )
        .contentShape(.rect(cornerRadius: AppLayout.tileRadius))
        .onTapGesture { Haptics.light(); onTap() }
        .contextMenu { menu }
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
        .onAppear { sweepProgress = effectiveCompleted ? 1 : 0 }
        .onChange(of: effectiveCompleted) { _, isLogged in
            if isLogged, habit.trackKind == .manual, !isPastDay {
                withAnimation(.easeOut(duration: 0.5)) { sweepProgress = 1 }
            } else {
                sweepProgress = isLogged ? 1 : 0
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens history. Long press for options.")
    }

    // MARK: - Menu

    @ViewBuilder
    private var menu: some View {
        if isPastDay {
            let label = habit.isCompleted(on: selectedDate) ? "Remove this day's log" : "Log this day"
            Button(label, systemImage: habit.isCompleted(on: selectedDate) ? "minus.circle" : "checkmark.circle") {
                onTogglePastDay()
            }
        } else if habit.isCompletedToday {
            Button("Undo today's log", systemImage: "arrow.uturn.backward") { onUndoToday() }
        } else {
            Button("Log today", systemImage: "checkmark.circle") {
                Haptics.success()
                SoundEffects.logChime()
                onLog()
            }
        }
        if habit.timerDurationSeconds > 0, !isPastDay {
            if timerIsActiveForThisHabit {
                Button("Stop timer", systemImage: "stop.circle", role: .destructive) {
                    Haptics.warning()
                    timerCenter.stop()
                }
            } else {
                Button("Start timer", systemImage: "timer") { onStartTimer() }
            }
        }
        Divider()
        Button("Edit", systemImage: "pencil") { Haptics.light(); onEdit() }
        Button("Arrange habits", systemImage: "arrow.up.arrow.down") { onArrange() }
        Button("Delete", systemImage: "trash", role: .destructive) { Haptics.warning(); onRequestDelete() }
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
            statusLine
                .padding(.top, 3)
            Spacer(minLength: 12)
            bottomSection
        }
        .padding(padding)
    }

    // Always present so a circular mask driven by `sweepProgress` can animate
    // it in. For manual habits the reveal sweeps from the slide knob's resting
    // end (bottom trailing); for health and timer habits it snaps in.
    private var completionGlow: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let half = SlideToLogTrack.trackHeight / 2
            let origin = CGPoint(x: w - padding - half, y: h - padding - half)
            let maxRadius = hypot(origin.x, origin.y)

            RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous)
                .fill(LinearGradient(
                    colors: [habit.color.opacity(0.30), habit.color.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .mask(
                    Circle()
                        .frame(width: maxRadius * 2 * sweepProgress, height: maxRadius * 2 * sweepProgress)
                        .position(origin)
                )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Header

    private var topRow: some View {
        HStack(alignment: .top) {
            IconChip(icon: habit.symbol, tint: habit.color, size: 30)
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
                .foregroundStyle(habit.color.glyphTone)
        }
    }

    // MARK: - Status line

    /// One quiet line under the name: the streak once there is one, and the
    /// cadence fact that matters today ("2 of 5 this week", "Due today").
    private var statusLine: some View {
        let streak = habit.displayStreak
        let cadence = cadenceStatus

        return HStack(spacing: 4) {
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
                    .foregroundStyle(cadence.highlighted ? AnyShapeStyle(habit.color.glyphTone) : AnyShapeStyle(.secondary))
            }
        }
        .font(.caption.weight(.medium).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    /// The schedule fact for this tile, or nil when the streak says enough.
    /// Highlighted means it asks for attention (due) or celebrates (target met).
    private var cadenceStatus: (text: String, highlighted: Bool)? {
        switch habit.frequency {
        case .daily:
            return habit.displayStreak > 0 ? nil : ("Daily", false)
        case .weekly:
            let count = habit.completionsInWeek(of: selectedDate).count
            return ("\(count) of \(habit.weeklyTarget) this week", count >= habit.weeklyTarget)
        case .interval:
            let every = "Every \(habit.intervalDays) days"
            guard !isPastDay, intervalRestingDays == nil, !habit.isCompletedToday else { return (every, false) }
            switch habit.daysUntilDue {
            case 0?: return ("Due today", true)
            case let d? where d < 0: return (d == -1 ? "1 day overdue" : "\(-d) days overdue", true)
            default: return (every, false)
            }
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
        return Button(action: onTogglePastDay) {
            HStack(spacing: 6) {
                Image(systemName: logged ? "checkmark.circle.fill" : "plus.circle")
                    .font(.footnote.weight(.semibold))
                Text(logged ? "Logged" : "Tap to log")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(logged ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .frame(maxWidth: .infinity, minHeight: SlideToLogTrack.trackHeight)
            .background(
                Capsule().fill(logged ? habit.color.opacity(0.28) : Color.white.opacity(0.08))
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
                onStartTimer()
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
            SlideToLogTrack(accent: habit.color, isLogged: habit.isCompletedToday) {
                onLog()
            }
        }
    }

    /// Days left on an interval countdown while the tile stays log-free; nil
    /// whenever the slide track belongs.
    private var intervalRestingDays: Int? {
        guard habit.frequency == .interval,
              !habit.isCompletedToday,
              let remaining = habit.daysUntilDue, remaining > 0 else { return nil }
        return remaining
    }

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
