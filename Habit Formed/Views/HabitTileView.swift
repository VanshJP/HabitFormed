import SwiftUI

/// Habit tile with three display modes:
/// - Manual: icon, title, streak, slide-to-log track
/// - HealthKit: icon, title, streak, live progress bar ("5.3k / 10k steps")
/// - Timer: icon, title, streak, week dots + play button
struct HabitTileView: View {
    let habit: Habit
    /// Date the home grid is currently displaying. Tile visuals (status badge,
    /// glow, bottom action) all reflect this date. Equals `.now` in normal use.
    var selectedDate: Date = .now
    /// True when the user is browsing a non-today date. Suppresses the context
    /// menu, slide-to-log, and timer start so past-day browsing is read-only.
    var isReadOnly: Bool = false
    let onTap: () -> Void
    let onLog: () -> Void
    let onEdit: () -> Void
    let onRequestDelete: () -> Void
    let onStartTimer: () -> Void

    @Environment(HealthKitService.self) private var health
    @Environment(TimerCenter.self) private var timerCenter
    @Environment(DayTracker.self) private var dayTracker

    // Drives the radial reveal of `completionGlow`. 0 = empty, 1 = card fully
    // bathed in the habit color. Animated from the slide track's release end
    // when the user logs via slide; snapped instantly for non-manual habits.
    @State private var sweepProgress: CGFloat = 0
    @State private var showStopConfirm: Bool = false
    /// When true the tile expands to show a GitHub-style activity heatmap
    /// just below the streak row. Toggled by tapping the streak label.
    @State private var showHeatMap: Bool = false

    /// Completion state for the date currently being browsed. Weekly habits
    /// "stay lit" for the entire calendar week containing `selectedDate` so
    /// the glow doesn't flicker on/off as you scrub between days.
    private var effectiveCompleted: Bool {
        if habit.frequency == .weekly {
            return !habit.completionsInWeek(of: selectedDate).isEmpty
        }
        return habit.isCompleted(on: selectedDate)
    }

    var body: some View {
        // Re-render at midnight so `isCompletedToday`-driven UI updates.
        let _ = dayTracker.today

        return ZStack(alignment: .topLeading) {
            completionGlow
            content
        }
        .frame(minHeight: 178)
        .glassCard(cornerRadius: 20, tint: tileTint)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture { Haptics.light(); onTap() }
        .conditionalContextMenu(isReadOnly == false) {
            Button("Edit", systemImage: "pencil")          { Haptics.light(); onEdit() }
            if !habit.isCompletedToday {
                Button("Log Today", systemImage: "checkmark.seal.fill") { Haptics.success(); SoundEffects.logChime(); onLog() }
            }
            if timerIsActiveForThisHabit && timerCenter.isActive {
                Button("Stop Timer", systemImage: "stop.circle", role: .destructive) {
                    Haptics.warning()
                    timerCenter.stop()
                }
            }
            Button("Delete", systemImage: "trash", role: .destructive) { Haptics.warning(); onRequestDelete() }
        }
        .confirmationDialog(
            "Stop timer for \(habit.title)?",
            isPresented: $showStopConfirm,
            titleVisibility: .visible
        ) {
            Button("Stop", role: .destructive) {
                Haptics.warning()
                timerCenter.stop()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Progress won't be logged.")
        }
        .onAppear { sweepProgress = effectiveCompleted ? 1 : 0 }
        .onChange(of: effectiveCompleted) { _, isLogged in
            if isLogged {
                if isManualHabit && !isReadOnly {
                    withAnimation(.easeOut(duration: 0.5)) { sweepProgress = 1 }
                } else {
                    sweepProgress = 1
                }
            } else {
                sweepProgress = 0
            }
        }
        .accessibilityLabel("\(habit.title), \(habit.displayStreak) \(habit.streakUnitLabel) streak")
        .accessibilityHint(isReadOnly ? "Tap to view history." : "Tap to view history. Long press for options.")
    }

    // MARK: - Layout

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow
            Spacer(minLength: 8)
            Text(habit.title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            streakRow
            Spacer(minLength: 10)
            bottomSection
            if showHeatMap {
                heatMap
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(14)
    }

    // Inline activity heatmap revealed by tapping the streak. Fills the
    // tile's full content width with a 12-week × 7-day grid so the chart
    // sits compactly under the action row without overshooting the tile.
    private var heatMap: some View {
        ActivityHeatMap(
            completionDates: habit.completionDates,
            accent: habit.color,
            weeks: 12,
            cellSpacing: 2,
            cornerRadius: 2
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Always present in the hierarchy so a circular mask driven by
    // `sweepProgress` can animate it in. For manual habits the reveal sweeps
    // from the slide track's release point (bottom-right of the card); for
    // HealthKit / Timer habits it snaps in instantly via `sweepProgress = 1`.
    private var completionGlow: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            // Anchor: 14pt card padding + 15pt knob radius from the right;
            // 14pt bottom padding + half of the 34pt slide track from the bottom.
            let origin = CGPoint(x: w - 29, y: h - 31)
            // Diameter must reach the farthest corner (top-left) when full.
            let maxRadius = hypot(origin.x, origin.y)

            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [habit.color.opacity(0.42), habit.color.opacity(0.12)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .mask(
                    Circle()
                        .frame(width: maxRadius * 2 * sweepProgress,
                               height: maxRadius * 2 * sweepProgress)
                        .position(origin)
                )
        }
        .allowsHitTesting(false)
    }

    private var isManualHabit: Bool {
        habit.source == .none && habit.timerDurationSeconds == 0
    }

    // MARK: - Header

    private var topRow: some View {
        HStack(alignment: .top) {
            iconBadge
            Spacer()
            statusBadge
        }
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(habit.color.opacity(0.28))
                .frame(width: 36, height: 36)
            Image(systemName: habit.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if effectiveCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(habit.color)
        } else if habit.frequency == .interval && habit.source == .none {
            // Interval cadence cue: tinted once the habit is due or overdue.
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 14))
                .foregroundStyle(habit.isDue ? habit.color : Color.white.opacity(0.38))
        } else if habit.source != .none {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.38))
        } else if habit.timerDurationSeconds > 0 {
            Image(systemName: "timer")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.38))
        }
    }

    // MARK: - Streak

    private var streakRow: some View {
        Button {
            Haptics.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                showHeatMap.toggle()
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(streakReadout.value)")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(streakReadout.unit)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Number + unit for the big row. Interval habits swap the streak for
    /// a live day-countdown while resting between due dates.
    private var streakReadout: (value: Int, unit: String) {
        if let remaining = intervalCountdownDays {
            return (remaining, remaining == 1 ? "day" : "days")
        }
        return (habit.displayStreak, habit.streakUnitLabel)
    }

    /// Days until a manual interval habit is next due, or nil when no
    /// countdown is ticking (not interval, never logged, or due/overdue).
    private var intervalCountdownDays: Int? {
        guard habit.frequency == .interval, habit.source == .none,
              let remaining = habit.daysUntilDue, remaining > 0 else { return nil }
        return remaining
    }

    // MARK: - Bottom section (varies by habit type)

    @ViewBuilder
    private var bottomSection: some View {
        if isReadOnly {
            // Past-day browse: collapse all interactive controls into a single
            // read-only pill that reflects the selected date.
            readOnlyStatusPill
        } else if habit.source != .none {
            healthProgressView
        } else if habit.timerDurationSeconds > 0 {
            timerRow
        } else {
            manualSlide
        }
    }

    private var readOnlyStatusPill: some View {
        HStack(spacing: 6) {
            Image(systemName: effectiveCompleted ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 12, weight: .bold))
            Text(effectiveCompleted ? "LOGGED" : "NOT LOGGED")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.2)
        }
        .foregroundStyle(effectiveCompleted ? .white : .white.opacity(0.55))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(effectiveCompleted ? habit.color.opacity(0.45) : Color.white.opacity(0.06))
        )
    }

    // HealthKit: progress bar + value / target. Switches between daily and
    // weekly aggregates based on the habit's frequency.
    private var healthProgressView: some View {
        let isWeekly = habit.frequency == .weekly
        let liveValue = (isWeekly
            ? health.liveWeeklyValues[habit.source.rawValue]
            : health.liveValues[habit.source.rawValue]) ?? 0
        let progress = min(liveValue / max(habit.targetValue, 1), 1.0)

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 2) {
                Text(formattedValue(liveValue))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(" / \(formattedTarget)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                Spacer(minLength: 0)
                if isWeekly {
                    Text("WEEK")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(progress >= 1 ? habit.color : habit.color.opacity(0.8))
                        .frame(width: max(6, geo.size.width * progress))
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: progress)
                }
            }
            .frame(height: 5)
        }
    }

    // Timer: week dots on the left, play/start button on the right
    private var timerRow: some View {
        HStack(spacing: 0) {
            WeekDotsView(completionDates: habit.completionDates)
            Spacer()
            Button {
                Haptics.medium()
                onStartTimer()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: timerIcon)
                        .font(.system(size: 9, weight: .bold))
                    Text(timerLabel)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(habit.isCompletedToday ? habit.color.opacity(0.35) : habit.color.opacity(0.85))
                )
            }
            .buttonStyle(.plain)
            .disabled(habit.isCompletedToday)
            // Inside-out gesture priority: this absorbs the long-press
            // before the parent contextMenu can claim it.
            .onLongPressGesture(minimumDuration: 0.6) {
                guard timerIsActiveForThisHabit else { return }
                Haptics.light()
                showStopConfirm = true
            }
        }
    }

    // Reflect the global TimerCenter state on the tile so the user can see
    // a running timer at a glance from the home grid.
    private var timerIsActiveForThisHabit: Bool { timerCenter.habitID == habit.id }

    private var timerIcon: String {
        if !timerIsActiveForThisHabit { return "play.fill" }
        return timerCenter.isRunning ? "waveform" : "pause.fill"
    }

    private var timerLabel: String {
        if timerIsActiveForThisHabit {
            let s = timerCenter.remainingSeconds
            return String(format: "%d:%02d", s / 60, s % 60)
        }
        return "\(habit.timerDurationSeconds / 60)m"
    }

    // Manual: slide-to-log track. For weekly habits a tiny "X / N THIS WEEK"
    // caption sits above the slide so the user can see weekly progress at a
    // glance; interval habits show their next-due cadence in the same slot.
    private var manualSlide: some View {
        VStack(alignment: .leading, spacing: 4) {
            if habit.frequency == .weekly {
                weeklyCountCaption
            } else if habit.frequency == .interval {
                cadenceCaption
            }
            SlideToLogTrack(accent: habit.color, isLogged: habit.isCompletedToday) {
                onLog()
            }
        }
    }

    private var weeklyCountCaption: some View {
        let count = habit.completionsThisWeek
        let target = habit.weeklyTarget
        let met = count >= target
        return Text("\(count) / \(target) THIS WEEK")
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(met ? habit.color : .white.opacity(0.42))
    }

    // Countdown status for interval habits, mirroring the weekly caption slot.
    private var cadenceCaption: some View {
        let remaining = habit.daysUntilDue
        let text: String
        let tint: Color
        switch remaining {
        case nil:
            text = "EVERY \(habit.intervalDays) DAYS"
            tint = .white.opacity(0.42)
        case 0?:
            text = "DUE TODAY"
            tint = habit.color
        case let d? where d < 0:
            text = "\(abs(d))D OVERDUE"
            tint = habit.color
        case let d?:
            text = "NEXT IN \(d)D"
            tint = .white.opacity(0.42)
        }
        return Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(tint)
    }

    // MARK: - Helpers

    private func formattedValue(_ value: Double) -> String {
        switch habit.source {
        case .steps, .activeCalories:
            return value >= 1000 ? String(format: "%.1fk", value / 1000) : "\(Int(value))"
        case .sleepHours, .standHours:
            return String(format: "%.1fh", value)
        case .mindfulMinutes, .exerciseMinutes:
            return "\(Int(value))m"
        case .walkingDistance:
            return String(format: "%.1fkm", value)
        case .flightsClimbed:
            return "\(Int(value))"
        case .none:
            return ""
        }
    }

    private var formattedTarget: String {
        switch habit.source {
        case .steps, .activeCalories:
            let t = habit.targetValue
            return t >= 1000 ? String(format: "%.0fk", t / 1000) : "\(Int(t))"
        case .sleepHours, .standHours:
            return String(format: "%.0fh", habit.targetValue)
        case .mindfulMinutes, .exerciseMinutes:
            return "\(Int(habit.targetValue))m"
        case .walkingDistance:
            return String(format: "%.0fkm", habit.targetValue)
        case .flightsClimbed:
            return "\(Int(habit.targetValue))"
        case .none:
            return ""
        }
    }

    private var tileTint: Color {
        effectiveCompleted ? habit.color.opacity(0.14) : AppColors.glassTintAccent
    }
}

// MARK: - Conditional contextMenu

private extension View {
    /// Applies `.contextMenu { content }` only when `enabled` is true. When
    /// disabled, the long-press gesture is suppressed entirely instead of
    /// presenting an empty menu container.
    @ViewBuilder
    func conditionalContextMenu<M: View>(
        _ enabled: Bool,
        @ViewBuilder content: () -> M
    ) -> some View {
        if enabled {
            self.contextMenu { content() }
        } else {
            self
        }
    }
}
