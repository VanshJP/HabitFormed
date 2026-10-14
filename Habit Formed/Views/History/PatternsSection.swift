import SwiftUI

/// What History noticed in the last eight weeks (`HabitInsights`), one line
/// each, and with Apple Intelligence one tip worded from those lines. Hidden
/// until there is something to say.
struct PatternsSection: View {
    let habits: [Habit]
    /// `habits`' tracks, in the same order.
    let tracks: [HabitTrack]
    /// Every log, newest first.
    let completions: [HabitCompletion]
    let today: Date

    @AppStorage(HabitInsights.tipKey) private var tip = ""
    @AppStorage(HabitInsights.tipSourceKey) private var tipSource = ""

    var body: some View {
        let insights = HabitInsights.find(in: inputs, today: today)
        if !insights.isEmpty {
            let source = ([String(today.timeIntervalSinceReferenceDate)] + insights.map(\.text)).joined(separator: "\n")
            GlassSection("Patterns") {
                Panel {
                    ForEach(insights) { insight in
                        let habit = habits.first { $0.id == insight.habitID }
                        ListRowLabel(
                            icon: habit?.symbol ?? "calendar",
                            tint: habit?.color ?? AppColors.primary,
                            title: insight.text,
                            trailing: .none
                        )
                    }
                    if tipSource == source, !tip.isEmpty {
                        ListRowLabel(icon: "sparkles", title: tip, trailing: .none)
                    }
                }
            }
            .task(id: source) { await askForTip(insights, source: source) }
        }
    }

    /// Each habit's days, and the times of logs made on their own day.
    /// Health logs are written by sync and backfills later by hand, and a log
    /// that answered a learned reminder shows the reminder, so none of them
    /// say when the habit is done.
    private var inputs: [InsightHabit] {
        let start = today.adding(days: -HabitInsights.windowDays)
        var times: [UUID: [Date]] = [:]
        for completion in completions {
            guard completion.date >= start else { break }
            guard !completion.followedReminder,
                  let id = completion.habit?.id,
                  completion.loggedAt.isSameDay(as: completion.date)
            else { continue }
            times[id, default: []].append(completion.loggedAt)
        }
        return zip(habits, tracks).map { habit, track in
            InsightHabit(title: habit.title, track: track, logTimes: habit.trackKind == .health ? [] : times[habit.id] ?? [])
        }
    }

    /// Asks the on-device model once per day and set of facts; a failure is
    /// remembered too, so it is not asked again on every visit.
    private func askForTip(_ insights: [Insight], source: String) async {
        guard tipSource != source, OnDeviceModel.isAvailable else { return }
        let facts = insights.map { "- \($0.text)" }.joined(separator: "\n")
        let reply = await OnDeviceModel.phrase("Facts:\n\(facts)", instructions: Self.instructions)
        guard !Task.isCancelled else { return }
        tip = reply.flatMap { $0.count <= 100 ? $0 : nil } ?? ""
        tipSource = source
    }

    private static let instructions = """
        You help someone keep their habits. From the facts given, write one kind, specific \
        suggestion they could try. Use only those facts, and name habits exactly as written. \
        One sentence under 80 characters, plain words, no emoji, no quotes, no dashes.
        """
}
