import Foundation
import UserNotifications

/// Owns all `UserNotifications` interactions: permission, per-habit
/// reminders that respect each habit's cadence, and one-shot timer
/// completion alerts.
///
/// Reminder ids use the `habit-reminder-` prefix and timer alerts use
/// `timer-`, so a reminder rebuild never touches timer alerts and vice
/// versa. Reminders are rebuilt from scratch on every `syncReminders`
/// call; iOS dedupes by identifier, making the rebuild idempotent.
@Observable
final class NotificationService {
    var isAuthorized: Bool = false
    var hasRequestedAuthorization: Bool = false

    /// Monotonic token so overlapping syncs can't interleave a remove
    /// from an older pass with adds from a newer one.
    private var syncGeneration = 0

    private static let reminderPrefix = "habit-reminder-"
    /// Rolling one-shots scheduled ahead for interval habits.
    private static let intervalHorizon = 4

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
                .requestAuthorization(options: [.alert, .sound])
            isAuthorized = granted
            hasRequestedAuthorization = true
        } catch {
            print("Notification authorization failed: \(error)")
            isAuthorized = false
            hasRequestedAuthorization = true
        }
    }

    // MARK: - Habit reminders

    /// Single entry point for reminder state. Refreshes permission,
    /// drops every pending reminder, and reschedules from current habit
    /// data. Safe to call as often as needed (launch, foreground,
    /// model changes).
    @MainActor
    func syncReminders(for habits: [Habit]) async {
        await refreshAuthorizationStatus()

        syncGeneration += 1
        let token = syncGeneration

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard token == syncGeneration else { return }
        let staleIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.reminderPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: staleIDs)

        guard isAuthorized else { return }

        for habit in habits where habit.reminderEnabled {
            for request in Self.reminderRequests(for: habit) {
                do {
                    try await center.add(request)
                } catch {
                    print("Failed to schedule reminder for \(habit.title): \(error)")
                }
                guard token == syncGeneration else { return }
            }
        }
    }

    /// Immediately drops one habit's reminders. Called directly from the
    /// delete flow so cleanup doesn't depend on any observer firing.
    func cancelReminders(habitID: UUID) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.reminderPrefix) && $0.contains(habitID.uuidString) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Builds every notification request a habit needs right now.
    ///
    /// - daily: repeating alert at the reminder time.
    /// - weekly: repeating alert at the reminder time; body reflects
    ///   this week's progress toward the target.
    /// - interval: rolling one-shots on upcoming cycle due dates (plus
    ///   catch-up nags while overdue). Never-logged interval habits get
    ///   a repeating nudge until the first log starts the countdown.
    private static func reminderRequests(for habit: Habit) -> [UNNotificationRequest] {
        switch habit.frequency {
        case .daily:
            let content = content(for: habit, body: "Time to log.")
            return [request(id: reminderID(habit), content: content, trigger: repeatingTrigger(habit))]

        case .weekly:
            let body = "\(habit.completionsThisWeek) of \(habit.weeklyTarget) this week."
            let content = content(for: habit, body: body)
            return [request(id: reminderID(habit), content: content, trigger: repeatingTrigger(habit))]

        case .interval:
            guard habit.lastCompletionDate != nil else {
                let content = content(for: habit, body: "Log to start the cycle.")
                return [request(id: reminderID(habit), content: content, trigger: repeatingTrigger(habit))]
            }
            return intervalReminderRequests(habit)
        }
    }

    /// One-shot per upcoming due date, horizon deep. Each app foreground
    /// or log re-syncs the chain, so fired slots are replaced with fresh
    /// ones anchored to the new last-completion date.
    private static func intervalReminderRequests(_ habit: Habit) -> [UNNotificationRequest] {
        let fireDates = Self.intervalFireDates(habit: habit, limit: intervalHorizon)
        return fireDates.enumerated().map { index, date in
            let suffix = index == 0 ? "" : "-\(index + 1)"
            let body = date.isToday ? "Due today." : "Time to log."
            let content = content(for: habit, body: body)

            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date
            )
            components.timeZone = Calendar.current.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            return request(
                id: "\(reminderID(habit))\(suffix)",
                content: content,
                trigger: trigger
            )
        }
    }

    /// Upcoming cycle boundaries at the reminder time-of-day. Anchored
    /// to the last log plus `intervalDays`; overdue boundaries are
    /// stepped past so the next nag lands on the next real slot.
    private static func intervalFireDates(habit: Habit, limit: Int) -> [Date] {
        let cal = Calendar.current
        let step = max(habit.intervalDays, 1)

        guard let last = habit.lastCompletionDate,
              var candidate = cal.date(
                bySettingHour: habit.reminderHour,
                minute: habit.reminderMinute,
                second: 0,
                of: last.adding(days: step)
              )
        else { return [] }

        while candidate <= Date() {
            guard let next = cal.date(byAdding: .day, value: step, to: candidate) else { return [] }
            candidate = next
        }

        var dates: [Date] = []
        for _ in 0..<limit {
            dates.append(candidate)
            guard let next = cal.date(byAdding: .day, value: step, to: candidate) else { break }
            candidate = next
        }
        return dates
    }

    // MARK: - Reminder builders

    private static func repeatingTrigger(_ habit: Habit) -> UNCalendarNotificationTrigger {
        var components = DateComponents()
        components.hour = habit.reminderHour
        components.minute = habit.reminderMinute
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    }

    private static func content(for habit: Habit, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = habit.title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .active
        content.threadIdentifier = habit.id.uuidString
        return content
    }

    private static func request(
        id: String, content: UNMutableNotificationContent, trigger: UNNotificationTrigger
    ) -> UNNotificationRequest {
        UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private static func reminderID(_ habit: Habit) -> String {
        "\(reminderPrefix)\(habit.id.uuidString)"
    }

    // MARK: - Timer completion

    /// Schedules a one-shot alert that fires when the timer hits zero.
    /// Re-call to overwrite an existing one (UN dedupes by identifier).
    func scheduleTimerCompletion(habitID: UUID, habitTitle: String, fireAt: Date) {
        let interval = fireAt.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(habitTitle) done!"
        content.body = "Your timer just wrapped up. Tap to log it."
        content.sound = .default
        content.interruptionLevel = .active
        content.threadIdentifier = habitID.uuidString

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.timerNotificationID(for: habitID),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Failed to schedule timer alert: \(error)") }
        }
    }

    func cancelTimerNotification(habitID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.timerNotificationID(for: habitID)])
    }

    private static func timerNotificationID(for habitID: UUID) -> String {
        "timer-\(habitID.uuidString)"
    }
}
