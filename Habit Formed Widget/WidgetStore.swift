import Foundation

/// The App Group shelf the app and the widget share: the latest
/// `WidgetSnapshot` and the logs tapped on the widget that the app has not
/// written yet. Every call is a no-op when the App Group is missing, so a
/// build without the entitlement still runs.
nonisolated enum WidgetStore {
    static let appGroup = "group.com.vansh.Habit-Formed"

    private static let snapshotKey = "widgetSnapshot"
    private static let pendingKey = "widgetPendingLogs"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    // MARK: - Snapshot

    static func loadSnapshot() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
    }

    // MARK: - Pending logs

    static func pendingLogs() -> [PendingWidgetLog] {
        guard let data = defaults?.data(forKey: pendingKey) else { return [] }
        return (try? JSONDecoder().decode([PendingWidgetLog].self, from: data)) ?? []
    }

    /// Queues a widget tap and marks it done in the snapshot.
    static func queue(_ log: PendingWidgetLog) {
        setPending(pendingLogs() + [log])
        if var snapshot = loadSnapshot() {
            snapshot.markDone(habitID: log.habitID, on: log.day)
            save(snapshot)
        }
    }

    /// Drops the logs the app has written, keeping any tapped since it read.
    static func removePending(_ written: [PendingWidgetLog]) {
        setPending(pendingLogs().filter { !written.contains($0) })
    }

    private static func setPending(_ logs: [PendingWidgetLog]) {
        guard let data = try? JSONEncoder().encode(logs) else { return }
        defaults?.set(data, forKey: pendingKey)
    }
}
