import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct Habit_Formed_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HabitTimerAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.75))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.attributes.habitSymbol)
                            .foregroundStyle(habitColor(context))
                        Text(context.attributes.habitTitle)
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isFinished {
                        timerText(context: context)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    } else {
                        Button(intent: TimerControlIntent()) {
                            HStack(spacing: 6) {
                                timerText(context: context)
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                Image(systemName: context.state.endDate != nil ? "pause.fill" : "play.fill")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isFinished {
                        Text("COMPLETE")
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                    } else if let endDate = context.state.endDate, endDate > .now {
                        let start = endDate.addingTimeInterval(-Double(context.attributes.totalSeconds))
                        ProgressView(timerInterval: start...endDate, countsDown: false)
                            .tint(habitColor(context))
                    } else {
                        ProgressView(value: staticProgress(context), total: 1.0)
                            .tint(habitColor(context).opacity(0.6))
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.habitSymbol)
                    .foregroundStyle(habitColor(context))
            } compactTrailing: {
                timerText(context: context)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(habitColor(context))
            } minimal: {
                Image(systemName: context.attributes.habitSymbol)
                    .foregroundStyle(habitColor(context))
            }
        }
    }

    // MARK: - Helpers

    private func habitColor(_ context: ActivityViewContext<HabitTimerAttributes>) -> Color {
        Color(hex: context.attributes.habitColorHex)
    }

    @ViewBuilder
    private func timerText(context: ActivityViewContext<HabitTimerAttributes>) -> some View {
        if context.state.isFinished {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if let endDate = context.state.endDate, endDate > .now {
            Text(timerInterval: .now...endDate, countsDown: true)
        } else if let remaining = context.state.pausedRemaining {
            Text(formatted(Int(remaining.rounded(.up))))
        } else {
            Text("00:00")
        }
    }

    private func staticProgress(_ context: ActivityViewContext<HabitTimerAttributes>) -> Double {
        let total = Double(context.attributes.totalSeconds)
        guard total > 0 else { return 0 }
        if context.state.isFinished { return 1.0 }
        if let endDate = context.state.endDate {
            let remaining = max(0, endDate.timeIntervalSinceNow)
            return min(1, max(0, (total - remaining) / total))
        }
        if let paused = context.state.pausedRemaining {
            return min(1, max(0, (total - paused) / total))
        }
        return 0
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let context: ActivityViewContext<HabitTimerAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: context.attributes.habitSymbol)
                .font(.title3)
                .foregroundStyle(Color(hex: context.attributes.habitColorHex))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.habitTitle)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                stateLabel
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 8)

            timerDisplay
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var timerDisplay: some View {
        if context.state.isFinished {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        } else {
            Button(intent: TimerControlIntent()) {
                HStack(spacing: 8) {
                    timerText
                    Image(systemName: context.state.endDate != nil ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(
                                context.state.endDate != nil
                                    ? Color.white.opacity(0.15)
                                    : Color(hex: context.attributes.habitColorHex)
                            )
                        )
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var timerText: some View {
        if let endDate = context.state.endDate, endDate > .now {
            Text(timerInterval: .now...endDate, countsDown: true)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(minWidth: 64, alignment: .trailing)
        } else if let remaining = context.state.pausedRemaining {
            let secs = Int(remaining.rounded(.up))
            Text(String(format: "%02d:%02d", secs / 60, secs % 60))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.6))
                .frame(minWidth: 64, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var stateLabel: some View {
        if context.state.isFinished {
            Text("Complete")
        } else if context.state.endDate != nil {
            Text("Running")
        } else if context.state.pausedRemaining != nil {
            Text("Paused")
        } else {
            Text("Ready")
        }
    }
}

// MARK: - Color Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
