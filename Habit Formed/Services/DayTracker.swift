import Foundation
import SwiftUI

/// Publishes the current calendar day so views that branch on
/// `Habit.isCompletedToday` re-render at midnight without forcing a
/// `NavigationStack` rebuild. Two triggers keep this honest:
///
/// 1. `Notification.Name.NSCalendarDayChanged` fires while the app is
///    foregrounded across midnight.
/// 2. A `scenePhase == .active` callback (wired up in `ContentView`)
///    calls `refresh()` because iOS sometimes suppresses
///    `NSCalendarDayChanged` after long suspensions.
@Observable
@MainActor
final class DayTracker {
    private(set) var today: Date = Date().startOfDay

    @ObservationIgnored
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Hop to MainActor since the NotificationCenter callback is
            // delivered on an arbitrary queue under Swift 6 isolation.
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    /// Recompute `today`. No-op if the date hasn't actually rolled over,
    /// so dependent views don't re-render unnecessarily.
    func refresh() {
        let now = Date().startOfDay
        if now != today { today = now }
    }
}
