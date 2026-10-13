import Foundation
import SwiftData
import WidgetKit

/// Keeps the Home Screen widgets current. The widget cannot open the habit
/// store, so the app writes what it shows (`WidgetSnapshot`) into the App
/// Group and turns the logs tapped on the widget into real ones.
///
/// Order matters on every pass: write the pending logs first, then the
/// snapshot, or the snapshot would undo the taps the widget already shows.
@MainActor
enum WidgetSync {
    /// Writes queued widget logs, then refreshes the snapshot.
    static func refresh(habits: [Habit], in context: ModelContext, today: Date = Date()) {
        applyPendingLogs(habits: habits, in: context)
        update(habits: habits, today: today)
    }

    /// Turns the widget's taps into logs, keeping the tap time so learned
    /// reminder times see when it really happened. A habit deleted since the
    /// tap, or a day already logged, is skipped.
    static func applyPendingLogs(habits: [Habit], in context: ModelContext) {
        let pending = WidgetStore.pendingLogs()
        guard !pending.isEmpty else { return }
        for log in pending {
            guard let habit = habits.first(where: { $0.id == log.habitID }) else { continue }
            habit.log(on: log.day, at: log.tappedAt, in: context)
        }
        try? context.save()
        WidgetStore.removePending(pending)
    }

    /// Writes the snapshot and reloads the widgets, only when what they show
    /// changed.
    static func update(habits: [Habit], today: Date = Date()) {
        let snapshot = makeSnapshot(habits: habits, today: today)
        guard snapshot != WidgetStore.loadSnapshot() else { return }
        WidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Every habit field the widget draws, so callers can skip a rebuild.
    static func signature(habits: [Habit], today: Date) -> String {
        let rows = habits.map { habit in
            [
                habit.id.uuidString,
                habit.title,
                habit.symbol,
                habit.colorHex,
                habit.frequencyRaw,
                habit.sourceRaw,
                String(habit.weeklyTarget),
                String(habit.intervalDays),
                String(habit.completions?.count ?? 0),
                String(habit.lastCompletionDate?.timeIntervalSince1970 ?? 0),
            ].joined(separator: "|")
        }
        return ([String(today.startOfDay.timeIntervalSince1970)] + rows).joined(separator: ";")
    }

    // MARK: - Snapshot

    static func makeSnapshot(habits: [Habit], today: Date) -> WidgetSnapshot {
        let day = today.startOfDay
        let tracks = habits.map(\.track)
        return WidgetSnapshot(
            today: page(habits: habits, tracks: tracks, day: day),
            tomorrow: page(habits: habits, tracks: tracks, day: day.adding(days: 1))
        )
    }

    /// One day as the widget shows it, computed as if `day` were today.
    private static func page(habits: [Habit], tracks: [HabitTrack], day: Date) -> WidgetSnapshot.Page {
        let summary = DayLedger.summary(on: day, tracks: tracks, today: day)
        let week = DayLedger.summaries(endingOn: day, count: 7, tracks: tracks, today: day)

        var open: [WidgetSnapshot.Item] = []
        var flexible: [WidgetSnapshot.Item] = []
        var done: [WidgetSnapshot.Item] = []
        for (habit, track) in zip(habits, tracks) {
            let status = track.status(on: day, today: day)
            let item = WidgetSnapshot.Item(
                id: habit.id,
                title: habit.title,
                symbol: habit.symbol,
                colorHex: habit.colorHex,
                isDone: status == .done,
                isExpected: status == .done || status == .open,
                canLog: habit.trackKind != .health
            )
            switch status {
            case .open: open.append(item)
            case .flexible: flexible.append(item)
            case .done: done.append(item)
            case .missed, .resting: break
            }
        }

        return WidgetSnapshot.Page(
            day: day,
            done: summary.done,
            expected: summary.expected,
            perfectStreak: DayLedger.perfectStreak(tracks: tracks, today: day),
            week: week.map { WidgetSnapshot.Day(date: $0.date, done: $0.done, expected: $0.expected) },
            items: open + flexible + done
        )
    }
}
