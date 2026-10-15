import SwiftUI

/// A row's timer control: play with the session length, the countdown while
/// it runs, or Done once logged. Tapping opens the timer.
struct RowTimerButton: View {
    let habit: Habit
    let onStart: () -> Void

    @Environment(TimerCenter.self) private var timerCenter

    var body: some View {
        let done = habit.isCompletedToday
        let active = timerCenter.habitID == habit.id
        return Button {
            Haptics.medium()
            onStart()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: glyph(done: done, active: active))
                    .font(.caption2.weight(.bold))
                    .symbolEffect(.variableColor.iterative, isActive: active && timerCenter.isRunning)
                    .symbolSwap(glyph(done: done, active: active))
                Text(done ? "Done" : (active ? timerText : "\(habit.timerDurationSeconds / 60) min"))
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: SlideToLogTrack.trackHeight)
            .background(Capsule().fill(done ? Color.white.opacity(0.18) : habit.color.opacity(0.85)))
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle())
        .disabled(done)
        .accessibilityLabel(active ? "Open timer" : "Start \(habit.timerDurationSeconds / 60) minute timer")
    }

    /// The same glyphs as a tile's timer: what the timer is doing, not what a
    /// tap would do.
    private func glyph(done: Bool, active: Bool) -> String {
        if done { return "checkmark" }
        if !active { return "play.fill" }
        return timerCenter.isRunning ? "waveform" : "pause.fill"
    }

    private var timerText: String {
        let s = timerCenter.remainingSeconds
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
