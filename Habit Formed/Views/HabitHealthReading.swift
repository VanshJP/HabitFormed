import SwiftUI

/// A health habit's reading on its page while today is open, where a log
/// button would be: Apple Health checks the habit off, so the page shows how
/// far along the day (or week) is. A reading stuck at zero says where Health
/// access lives, since iOS never tells an app it was declined.
struct HabitHealthReading: View {
    let habit: Habit
    @Environment(HealthKitService.self) private var health

    var body: some View {
        let weekly = habit.frequency == .weekly
        let value = (weekly ? health.liveWeeklyValues : health.liveValues)[habit.source.rawValue] ?? 0
        let fraction = habit.targetValue > 0 ? value / habit.targetValue : 0

        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(habit.source.compactValue(value))
                        .font(.metricValue)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: value))
                        .motion(AppMotion.snap, value: value)
                    Text("of \(habit.source.compactValue(habit.targetValue))\(habit.source.compactUnit)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if weekly {
                        Text("This week")
                            .eyebrowStyle()
                    }
                }
                MeterBar(fraction: fraction, color: habit.color.glyphTone, height: 6)
                    .motion(AppMotion.settle, value: fraction)
                Text(caption(value: value, weekly: weekly))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func caption(value: Double, weekly: Bool) -> String {
        if weekly && habit.isCompletedThisWeek { return "Checked off this week" }
        if value == 0 { return "Stuck at 0? Check Settings › Privacy & Security › Health › Habit Formed" }
        return "Checks itself off when you get there"
    }
}
