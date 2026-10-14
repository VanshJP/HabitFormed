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
