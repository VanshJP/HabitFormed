import Foundation
import UserNotifications

/// Owns all `UserNotifications` interactions: permission, daily habit
/// reminders (per-habit calendar triggers), and one-shot timer completion
/// alerts. Habit reminders use the `habit-reminder-` id prefix; timer
/// alerts use `timer-` so the two never trample each other.
@Observable
final class NotificationService {
    var isAuthorized: Bool = false
    var hasRequestedAuthorization: Bool = false

    // MARK: - Authorization

    @MainActor
    func refreshAuthorizationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = (status.authorizationStatus == .authorized || status.authorizationStatus == .provisional)
    }

    @MainActor
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
            isAuthorized = granted
            hasRequestedAuthorization = true
        } catch {
            isAuthorized = false
            hasRequestedAuthorization = true
        }
    }

    // MARK: - Habit reminders

    /// Drops every `habit-reminder-*` request and reschedules from scratch.
    /// Cheap because we only ever have a few habits.
    @MainActor
    func rescheduleHabitReminders(_ habits: [Habit]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let staleIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("habit-reminder-") }
        center.removePendingNotificationRequests(withIdentifiers: staleIDs)

        guard isAuthorized else { return }

        for habit in habits where habit.reminderEnabled {
            let id = "habit-reminder-\(habit.id.uuidString)"

            let content = UNMutableNotificationContent()
            content.title = habit.title
            content.body = habit.streak > 0
                ? "Keep your \(habit.streak)-day streak alive."
                : "Time to log this habit."
            content.sound = .default
            content.interruptionLevel = .active
            content.threadIdentifier = "habit-reminder"

            var components = DateComponents()
            components.hour = habit.reminderHour
            components.minute = habit.reminderMinute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            try? await center.add(request)
        }
    }

    // MARK: - Timer completion

    /// Schedules a one-shot, time-sensitive notification that fires when
    /// the timer hits zero. Re-call to overwrite an existing one (UN
    /// dedupes by identifier).
    func scheduleTimerCompletion(habitID: UUID, habitTitle: String, fireAt: Date) {
        let interval = fireAt.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(habitTitle) — done!"
        content.body = "Your timer just wrapped up. Tap to log it."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "habit-timer"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.timerNotificationID(for: habitID),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelTimerNotification(habitID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.timerNotificationID(for: habitID)])
    }

    private static func timerNotificationID(for habitID: UUID) -> String {
        "timer-\(habitID.uuidString)"
    }
}
