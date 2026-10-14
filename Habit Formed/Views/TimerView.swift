import SwiftUI
import SwiftData

/// Foreground UI for the global `TimerCenter`. The ring + countdown text
/// live inside a `TimelineView(.animation)` so the trim animates against
/// the screen's refresh rate rather than a discrete tick. That way,
/// pressing Start / Pause / Resume never snaps the ring forward or
/// backward.
struct TimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerCenter.self) private var center

    let habit: Habit

    @State private var showResetConfirm: Bool = false
    @State private var showStopConfirm: Bool = false
    @State private var didAutoFinish: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            AppBackground(style: .recording)

            VStack(spacing: 28) {
                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: habit.symbol)
                        .foregroundStyle(habit.color.glyphTone)
                    Text(habit.title)
                        .foregroundStyle(.white)
                }
                .font(.headline)

                ring

                sessionFootnote

                controls

                Spacer()

                if isOurTimer && center.isActive {
                    Button("Stop timer") {
                        Haptics.light()
                        showStopConfirm = true
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: AppLayout.minHitTarget)
                    .buttonStyle(.textLink)
                    .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 32)
            .readableColumn()

            SessionCloseButton(label: "Close timer") {
                Haptics.light()
                dismiss()
            }
            .padding(AppLayout.pageHorizontal)
        }
        .interactiveDismissDisabled(false)
        .onAppear { Haptics.medium() }
        // Watch for completion in a low-frequency loop so we can auto-log
        // and buzz exactly once when the timer hits zero. Cancelled when
        // the view disappears.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                if isOurTimer, center.hasFinished, !didAutoFinish {
                    didAutoFinish = true
                    Haptics.success()
                    SoundEffects.logChime()
                    center.finish(in: modelContext, habit: habit)
                }
            }
        }
        .confirmationDialog(
            "Reset timer?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset to \(habit.timerDurationSeconds / 60) min", role: .destructive) {
                Haptics.warning()
                center.reset()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("This session's progress will be lost.")
        }
        .confirmationDialog(
            "Stop the timer for \(habit.title)?",
            isPresented: $showStopConfirm,
            titleVisibility: .visible
        ) {
            Button("Stop", role: .destructive) {
                Haptics.warning()
                center.stop()
                dismiss()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("This session won't be logged.")
        }
    }

    // MARK: - Ring

    private var ring: some View {
        TimelineView(.animation) { context in
            let total = isOurTimer ? Double(center.totalSeconds) : Double(habit.timerDurationSeconds)
            let interval: TimeInterval = isOurTimer
                ? center.remainingInterval(at: context.date)
                : TimeInterval(habit.timerDurationSeconds)
            let prog = total > 0 ? min(1, max(0, (total - interval) / total)) : 0
            let displaySeconds = max(0, Int(interval.rounded(.up)))
            let isFinished = isOurTimer && center.endDate != nil && interval <= 0

            ZStack {
                Circle()
                    .stroke(AppColors.meterTrack, lineWidth: 14)

                Circle()
                    .trim(from: 0, to: prog)
                    // One flat colour, as the mini banner's ring: nothing draws
                    // its own gradient.
                    .stroke(habit.color.glyphTone, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 6) {
                    Text(formatted(displaySeconds))
                        .font(.displayNumeral)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .motion(AppMotion.snap, value: displaySeconds)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(stateLabel(isFinished: isFinished))
                        .eyebrowStyle()
                }
                .padding(.horizontal, 24)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(displaySeconds / 60) minutes \(displaySeconds % 60) seconds left, \(stateLabel(isFinished: isFinished))")
        }
        .frame(width: 280, height: 280)
    }

    private var sessionFootnote: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let interval = isOurTimer
                ? center.remainingInterval(at: context.date)
                : TimeInterval(habit.timerDurationSeconds)
            let total = center.totalSeconds
            let elapsed = max(0, total - Int(interval.rounded(.up)))
            if isOurTimer && center.isActive && elapsed > 0 && interval > 0 {
                Text("\(formatted(elapsed)) completed this session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Color.clear.frame(height: 16)
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 12) {
            GlassButton(title: "Reset", icon: "arrow.counterclockwise", style: .secondary, size: .large, fullWidth: true) {
                guard isOurTimer else { return }
                Haptics.light()
                showResetConfirm = true
            }
            .disabled(!isOurTimer || !canReset)

            GlassButton(title: primaryTitle, icon: primaryIcon, style: .primary, size: .large, fullWidth: true) {
                Haptics.medium()
                handlePrimary()
            }
        }
    }

    // MARK: - State derivation

    private var isOurTimer: Bool { center.habitID == habit.id }

    /// Reset is meaningful only when there's actually progress to throw
    /// away. Disabling it on a fresh-start session removes the chance
    /// to accidentally hit it before you've done anything anyway.
    private var canReset: Bool {
        isOurTimer && Int(center.remainingInterval(at: Date()).rounded(.up)) < center.totalSeconds
    }

    private func stateLabel(isFinished: Bool) -> String {
        guard isOurTimer else { return "Ready" }
        if isFinished { return "Done" }
        if center.isRunning { return "Running" }
        if center.isPaused { return "Paused" }
        return "Ready"
    }

    private var primaryIcon: String {
        if isOurTimer && center.hasFinished { return "checkmark" }
        if !isOurTimer { return "play.fill" }
        return center.isRunning ? "pause.fill" : "play.fill"
    }

    private var primaryTitle: String {
        if isOurTimer && center.hasFinished { return "Done" }
        if !isOurTimer { return "Start" }
        return center.isRunning ? "Pause" : "Resume"
    }

    private func handlePrimary() {
        if isOurTimer && center.hasFinished {
            center.finish(in: modelContext, habit: habit)
            dismiss()
            return
        }
        if !isOurTimer {
            center.start(habit: habit)
            return
        }
        if center.isRunning {
            center.pause()
        } else {
            center.resume(habit: habit)
        }
    }

    // MARK: - Format

    private func formatted(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
