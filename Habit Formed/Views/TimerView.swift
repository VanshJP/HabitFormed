import SwiftUI
import SwiftData

/// Foreground UI for the global `TimerCenter`. The ring + countdown text
/// live inside a `TimelineView(.animation)` so the trim animates against
/// the screen's refresh rate rather than a discrete tick — that way
/// pressing Start / Pause / Resume never snaps the ring forward or
/// backward.
struct TimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerCenter.self) private var center

    let habit: Habit

    @State private var showResetConfirm: Bool = false
    @State private var didAutoFinish: Bool = false

    var body: some View {
        ZStack {
            AppBackground(style: .focus).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Text(habit.title.uppercased())
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))

                ring

                sessionFootnote

                controls

                Spacer()

                Button(role: .cancel) {
                    Haptics.light()
                    dismiss()
                } label: {
                    Text("Close")
                }
                .foregroundStyle(.white.opacity(0.65))
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
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
            Text("You'll lose this session's progress.")
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
                    .stroke(Color.white.opacity(0.08), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: prog)
                    .stroke(
                        LinearGradient(
                            colors: [habit.color, habit.color.opacity(0.6)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 6) {
                    Image(systemName: isFinished ? "checkmark.seal.fill" : habit.symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(formatted(displaySeconds))
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(stateLabel(isFinished: isFinished))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
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
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                Color.clear.frame(height: 16)
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                guard isOurTimer else { return }
                Haptics.light()
                showResetConfirm = true
            } label: {
                controlLabel(icon: "arrow.counterclockwise", title: "Reset")
            }
            .disabled(!isOurTimer || !canReset)

            Button {
                Haptics.medium()
                handlePrimary()
            } label: {
                controlLabel(icon: primaryIcon, title: primaryTitle, primary: true)
            }
        }
    }

    private func controlLabel(icon: String, title: String, primary: Bool = false) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.system(size: 13, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(primary ? habit.color.opacity(0.85) : Color.white.opacity(0.08))
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
        guard isOurTimer else { return "READY" }
        if isFinished { return "DONE" }
        if center.isRunning { return "RUNNING" }
        if center.isPaused { return "PAUSED" }
        return "READY"
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
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
