import Foundation
import UserNotifications

/// Owns all `UserNotifications` interactions: permission, per-habit
/// reminders that respect each habit's cadence, the daily report nudge, and
/// one-shot timer completion alerts, and the Sunday recap nudge.
///
/// Reminder ids use the `habit-reminder-` prefix, timer alerts use `timer-`,
/// and the report nudge is `report-reminder`, so a reminder rebuild never
/// touches the others. Reminders are rebuilt from scratch on every `syncReminders`
/// call; iOS dedupes by identifier, making the rebuild idempotent.
@Observable
final class NotificationService {
    var isAuthorized: Bool = false
    var hasRequestedAuthorization: Bool = false

    /// Monotonic token so overlapping syncs can't interleave a remove
    /// from an older pass with adds from a newer one.
    private var syncGeneration = 0

    private static let reminderPrefix = "habit-reminder-"
    /// Habit reminders carry a "Log it" action, so a reminder can be answered
    /// from the notification without opening the app.
    nonisolated static let reminderCategory = "habit-reminder"
    nonisolated static let logAction = "log"
    nonisolated static let habitIDKey = "habitID"
    /// Rolling one-shots scheduled ahead for interval habits.
    private static let intervalHorizon = 4
    /// iOS keeps 64 pending requests per app; habit reminders stay under
    /// this so the report, recap and timer alerts always fit.
    private static let habitReminderBudget = 56

    // MARK: - Authorization

    /// Turned off for the app in iOS Settings, so a reminder switch that is
    /// on can say why nothing will come.
    var isDenied: Bool = false

    @MainActor
    func refreshAuthorizationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = (status.authorizationStatus == .authorized || status.authorizationStatus == .provisional)
        isDenied = status.authorizationStatus == .denied
    }

    @MainActor
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            isAuthorized = granted
            isDenied = !granted
            hasRequestedAuthorization = true
        } catch {
            print("Notification authorization failed: \(error)")
            isAuthorized = false
            hasRequestedAuthorization = true
        }
    }

    // MARK: - Categories

    /// Registers the "Log it" action. Call once at launch, before any
    /// reminder can be delivered.
    func registerCategories() {
        let log = UNNotificationAction(
            identifier: Self.logAction,
            title: "Log it",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "checkmark")
        )
        let reminder = UNNotificationCategory(
            identifier: Self.reminderCategory,
            actions: [log],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([reminder])
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

        // Splitting a week to skip a handled day costs six more requests;
        // habits past the budget keep their plain daily alert.
        let reminding = habits.filter(\.reminderEnabled)
        var spare = Self.habitReminderBudget - reminding.reduce(0) { $0 + Self.baseRequestCount($1) }

        for habit in reminding {
            let picked = habit.pickedReminderDays != nil
            let splitWeek = picked || (spare >= 6 && Self.hasHandledDay(habit))
            if splitWeek && !picked { spare -= 6 }
            for request in Self.reminderRequests(for: habit, splitWeek: splitWeek) {
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
    /// - daily: repeating alert at the reminder time, or with `splitWeek`
    ///   one alert per weekday so a day already handled stays quiet. Picked
    ///   days always split, keeping only those weekdays.
    /// - weekly: the same; body reflects this week's progress toward the
    ///   target, and a week whose target is met stays quiet.
    /// - interval: rolling one-shots on upcoming cycle due dates (plus
    ///   catch-up nags while overdue). Never-logged interval habits get
    ///   a repeating nudge until the first log starts the countdown.
    private static func reminderRequests(for habit: Habit, splitWeek: Bool) -> [UNNotificationRequest] {
        switch habit.frequency {
        case .daily:
            let content = content(for: habit, body: dailyBody(for: habit))
            if splitWeek { return weekRequests(habit, content: content) }
            return [request(id: reminderID(habit), content: content, trigger: repeatingTrigger(habit))]

        case .weekly:
            let body = "\(habit.completionsThisWeek) of \(habit.weeklyTarget) this week."
            let content = content(for: habit, body: body)
            if splitWeek { return weekRequests(habit, content: content) }
            return [request(id: reminderID(habit), content: content, trigger: repeatingTrigger(habit))]

        case .interval:
            guard habit.lastCompletionDate != nil else {
                let content = content(for: habit, body: "Log to start the cycle.")
                return [request(id: reminderID(habit), content: content, trigger: repeatingTrigger(habit))]
            }
            return intervalReminderRequests(habit)
        }
    }

    /// Requests a habit needs before any week is split. Picked days are
    /// already one alert each.
    private static func baseRequestCount(_ habit: Habit) -> Int {
        if let days = habit.pickedReminderDays { return days.count }
        return habit.frequency == .interval && habit.lastCompletionDate != nil ? intervalHorizon : 1
    }

    // MARK: - Skipping handled days

    /// The next seven firings at the reminder time, one per weekday,
    /// starting with today's while it is still ahead, keeping only the
    /// picked days.
    private static func upcomingFirings(_ habit: Habit, now: Date = Date()) -> [Date] {
        let calendar = Calendar.current
        let time = habit.reminderFireTime
        guard var first = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: now) else {
            return []
        }
        if first <= now { first = first.adding(days: 1) }
        let firings = (0..<7).map { first.adding(days: $0) }
        guard let days = habit.pickedReminderDays else { return firings }
        return firings.filter { days.contains(calendar.component(.weekday, from: $0)) }
    }

    /// A firing that would nag about a day already handled: one that is
    /// logged, or for a weekly habit, one in a week whose target is met.
    private static func isHandled(_ firing: Date, habit: Habit) -> Bool {
        if habit.isCompleted(on: firing) { return true }
        return habit.frequency == .weekly
            && habit.completionsInWeek(of: firing).count >= habit.weeklyTarget
    }

    private static func hasHandledDay(_ habit: Habit) -> Bool {
        guard habit.frequency != .interval else { return false }
        return upcomingFirings(habit).contains { isHandled($0, habit: habit) }
    }

    /// One alert per weekday. A weekday whose next firing is handled gets a
    /// one-shot a week later instead of a repeating alert, so it comes back
    /// even if the app is not opened again; the next sync, on any foreground
    /// or log, folds the week back into one daily alert.
    private static func weekRequests(_ habit: Habit, content: UNMutableNotificationContent) -> [UNNotificationRequest] {
        let calendar = Calendar.current
        let time = habit.reminderFireTime
        return upcomingFirings(habit).enumerated().map { index, firing in
            let handled = isHandled(firing, habit: habit)
            let firstFire = handled ? firing.adding(days: 7) : firing
            let trigger: UNCalendarNotificationTrigger
            if handled {
                var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: firstFire)
                parts.timeZone = calendar.timeZone
                trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            } else {
                var parts = DateComponents()
                parts.weekday = calendar.component(.weekday, from: firing)
                parts.hour = time.hour
                parts.minute = time.minute
                trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
            }
            let dayContent = habit.frequency == .weekly
                ? weeklyContent(habit, base: content, firstFire: firstFire)
                : content
            return request(id: "\(reminderID(habit))-d\(index)", content: dayContent, trigger: trigger)
        }
    }

    /// A weekly alert whose first firing lands in a later week starts that
    /// week at zero, not at this week's count.
    private static func weeklyContent(
        _ habit: Habit, base: UNMutableNotificationContent, firstFire: Date
    ) -> UNMutableNotificationContent {
        guard !Calendar.current.isDate(firstFire, equalTo: Date(), toGranularity: .weekOfYear),
              let fresh = base.mutableCopy() as? UNMutableNotificationContent else { return base }
        fresh.body = "0 of \(habit.weeklyTarget) this week."
        return fresh
    }

    // MARK: - Interval chains

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
                bySettingHour: habit.reminderFireTime.hour,
                minute: habit.reminderFireTime.minute,
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
        let time = habit.reminderFireTime
        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    }

    /// Says why the reminder came now when the time was learned.
    private static func dailyBody(for habit: Habit) -> String {
        guard habit.reminderLearnsTime, let usual = habit.usualLogMinute else { return "Time to log." }
        return "You usually log this around \(ReminderTime(minuteOfDay: usual).label)."
    }

    private static func content(for habit: Habit, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = habit.title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .active
        content.threadIdentifier = habit.id.uuidString
        content.userInfo = [habitIDKey: habit.id.uuidString]
        // Health habits log themselves from Apple Health, so they get no action.
        if habit.trackKind != .health {
            content.categoryIdentifier = reminderCategory
        }
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

    // MARK: - Report reminder

    private static let reportReminderID = "report-reminder"

    /// The evening nudge to send the day's report: one repeating alert at the
    /// chosen time, or none. Asks for permission the moment it is turned on.
    @MainActor
    func syncReportReminder(enabled: Bool, hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.reportReminderID])
        guard enabled else { return }

        await refreshAuthorizationStatus()
        if !isAuthorized { await requestAuthorization() }
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Today's report"
        content.body = "Send today's report to your people before the day ends."
        content.sound = .default
        content.interruptionLevel = .active

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.reportReminderID, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule report reminder: \(error)")
        }
    }

    // MARK: - Recap reminder

    private static let recapReminderID = "recap-reminder"

    /// Sundays at 7 PM, the nudge to send the week's recap. Asks for
    /// permission the moment it is turned on.
    @MainActor
    func syncRecapReminder(enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.recapReminderID])
        guard enabled else { return }

        await refreshAuthorizationStatus()
        if !isAuthorized { await requestAuthorization() }
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your week recap"
        content.body = "See how the last seven days went, then send the recap."
        content.sound = .default
        content.interruptionLevel = .active

        var components = DateComponents()
        components.weekday = 1
        components.hour = 19
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.recapReminderID, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule recap reminder: \(error)")
        }
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
