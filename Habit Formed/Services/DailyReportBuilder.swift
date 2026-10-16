import Foundation

/// Builds a `DailyReport` from live habits. Runs on the main actor because it
/// reads SwiftData models; everything it returns is a plain value.
enum DailyReportBuilder {
    /// - Parameters:
    ///   - habits: every habit, in grid order. Hidden ones are left off.
    ///   - liveValues: today's HealthKit readings by source, used for health
    ///     habits on today's report. Past days use the logged value.
    static func build(
        habits: [Habit],
        day: Date,
        options: ReportOptions,
        name: String,
        health: DayHealthMetrics,
        liveValues: [String: Double] = [:],
        liveWeeklyValues: [String: Double] = [:]
    ) -> DailyReport {
        let day = day.startOfDay
        let isToday = day.isToday
        let included = habits.filter { !options.hiddenHabitIDs.contains($0.id) }
        let tracks = included.map(\.track)
        let summary = DayLedger.summary(on: day, tracks: tracks)

        var items: [DailyReport.Item] = []
        for (habit, track) in zip(included, tracks) {
            let status = track.status(on: day)
            guard status != .resting else { continue }
            items.append(item(
                for: habit,
                track: track,
                status: status,
                day: day,
                isToday: isToday,
                liveValues: liveValues,
                liveWeeklyValues: liveWeeklyValues
            ))
        }

        return DailyReport(
            date: day,
            isToday: isToday,
            name: name,
            items: items,
            done: summary.done,
            expected: summary.expected,
            health: health
        )
    }

    // MARK: - Items

    private static func item(
        for habit: Habit,
        track: HabitTrack,
        status: DayStatus,
        day: Date,
        isToday: Bool,
        liveValues: [String: Double],
        liveWeeklyValues: [String: Double]
    ) -> DailyReport.Item {
        let streak = habit.displayStreak(asOf: day)
        let entry = habit.completion(on: day)
        let note = entry?.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let week = Date.trailingDays(7, endingOn: day).map { track.logDays.contains($0) }

        return DailyReport.Item(
            id: habit.id,
            title: habit.title,
            symbol: habit.symbol,
            colorHex: habit.colorHex,
            status: status,
            detail: detail(
                for: habit,
                track: track,
                status: status,
                day: day,
                isToday: isToday,
                loggedValue: entry?.value,
                liveValues: liveValues,
                liveWeeklyValues: liveWeeklyValues
            ),
            streak: streak,
            streakUnit: habit.streakUnit(for: streak),
            note: (note?.isEmpty ?? true) ? nil : note,
            week: week
        )
    }

    private static func detail(
        for habit: Habit,
        track: HabitTrack,
        status: DayStatus,
        day: Date,
        isToday: Bool,
        loggedValue: Double?,
        liveValues: [String: Double],
        liveWeeklyValues: [String: Double]
    ) -> String? {
        if habit.source != .none {
            let weekly = habit.frequency == .weekly
            let live = isToday
                ? (weekly ? liveWeeklyValues[habit.source.rawValue] : liveValues[habit.source.rawValue])
                : nil
            guard let value = live ?? loggedValue else {
                return status == .done ? nil : "Under target"
            }
            let range = weekly ? " this week" : ""
            return "\(habit.source.compactValue(value)) of \(habit.source.compactValue(habit.targetValue))\(habit.source.compactUnit)\(range)"
        }

        switch habit.frequency {
        case .weekly:
            return "\(track.weekCount(through: day))/\(habit.weeklyTarget) this week"
        case .interval:
            switch status {
            case .open: return "Due today"
            case .missed: return "Overdue"
            default:
                if habit.timerDurationSeconds > 0 { return "\(habit.timerDurationSeconds / 60) min" }
                return "Every \(habit.intervalDays) days"
            }
        case .daily:
            return habit.timerDurationSeconds > 0 ? "\(habit.timerDurationSeconds / 60) min" : nil
        }
    }
}
