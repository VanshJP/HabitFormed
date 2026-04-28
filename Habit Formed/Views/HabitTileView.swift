import SwiftUI

/// Habit tile with three display modes:
/// - Manual: icon, title, streak, slide-to-log track
/// - HealthKit: icon, title, streak, live progress bar ("5.3k / 10k steps")
/// - Timer: icon, title, streak, week dots + play button
struct HabitTileView: View {
    let habit: Habit
    let onTap: () -> Void
    let onLog: () -> Void
    let onEdit: () -> Void
    let onRequestDelete: () -> Void
    let onStartTimer: () -> Void

    @Environment(HealthKitService.self) private var health
    @Environment(TimerCenter.self) private var timerCenter

    // Drives the radial reveal of `completionGlow`. 0 = empty, 1 = card fully
    // bathed in the habit color. Animated from the slide track's release end
    // when the user logs via slide; snapped instantly for non-manual habits.
    @State private var sweepProgress: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            completionGlow
            content
        }
        .frame(height: 178)
        .glassCard(cornerRadius: 20, tint: tileTint)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture { Haptics.light(); onTap() }
        .contextMenu {
            Button("Edit", systemImage: "pencil")          { Haptics.light(); onEdit() }
            if !habit.isCompletedToday {
                Button("Log Today", systemImage: "checkmark.seal.fill") { Haptics.success(); onLog() }
            }
            Button("Delete", systemImage: "trash", role: .destructive) { Haptics.warning(); onRequestDelete() }
        }
        .onAppear { sweepProgress = habit.isCompletedToday ? 1 : 0 }
        .onChange(of: habit.isCompletedToday) { _, isLogged in
            if isLogged {
                if isManualHabit {
                    withAnimation(.easeOut(duration: 0.5)) { sweepProgress = 1 }
                } else {
                    sweepProgress = 1
                }
            } else {
                sweepProgress = 0
            }
        }
        .accessibilityLabel("\(habit.title), \(habit.streak) day streak")
        .accessibilityHint("Tap to view history. Long press for options.")
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
        }
        .padding(14)
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
        if habit.isCompletedToday {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(habit.color)
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
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("\(habit.streak)")
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(habit.isCompletedToday ? .white : AppColors.streakColor(for: habit.streak))
            Text(habit.streak == 1 ? "day" : "days")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(habit.isCompletedToday ? .white.opacity(0.7) : .white.opacity(0.42))
        }
    }

    // MARK: - Bottom section (varies by habit type)

    @ViewBuilder
    private var bottomSection: some View {
        if habit.source != .none {
            healthProgressView
        } else if habit.timerDurationSeconds > 0 {
            timerRow
        } else {
            manualSlide
        }
    }

    // HealthKit: progress bar + value / target
    private var healthProgressView: some View {
        let liveValue = health.liveValues[habit.source.rawValue] ?? 0
        let progress = min(liveValue / max(habit.targetValue, 1), 1.0)

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 2) {
                Text(formattedValue(liveValue))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(" / \(formattedTarget)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
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
            WeekDotsView(completionDates: habit.completionDates, accent: habit.color)
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

    // Manual: slide-to-log track
    private var manualSlide: some View {
        SlideToLogTrack(accent: habit.color, isLogged: habit.isCompletedToday) {
            onLog()
        }
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
        habit.isCompletedToday ? habit.color.opacity(0.14) : AppColors.glassTintAccent
    }
}
