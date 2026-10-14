import Foundation
import SwiftData
import UserNotifications

extension Notification.Name {
    /// Posted when the user taps a timer completion alert; carries the
    /// habit UUID in `userInfo["habitID"]`.
    static let habitOpenTimerFromNotification = Notification.Name("habitOpenTimerFromNotification")
    /// Posted when the user taps the evening report reminder.
    static let habitOpenReportFromNotification = Notification.Name("habitOpenReportFromNotification")
    /// Posted when the user taps the Sunday recap reminder.
    static let habitOpenRecapFromNotification = Notification.Name("habitOpenRecapFromNotification")
}

/// `UNUserNotificationCenterDelegate` attached at app launch.
///
/// Two jobs:
/// 1. Show banners even while the app is foregrounded (otherwise iOS
///    silently suppresses alerts the user is staring at).
/// 2. Route taps into the app: timer alerts via
///    `Notification.Name.habitOpenTimerFromNotification` (the habit's timer
///    sheet) and the report reminder via `.habitOpenReportFromNotification`
///    (today's report). Habit reminder taps just launch; their "Log it"
///    action logs today in the background through `modelContainer`.
@MainActor
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    /// The app's store, set at launch so a reminder's action can log.
    var modelContainer: ModelContainer?

    /// A report or recap tap that may have arrived before any view was
    /// listening. `RootView` takes it when it appears, so a cold launch from
    /// the reminder still lands on the sheet.
    static var pendingRoute: Notification.Name?

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.list, .banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier

        if response.actionIdentifier == NotificationService.logAction,
           let raw = response.notification.request.content.userInfo[NotificationService.habitIDKey] as? String,
           let habitID = UUID(uuidString: raw) {
            // The handler runs after the log and the reminder rebuild, so iOS
            // keeps the app awake long enough for both.
            Task { @MainActor in
                if let container = self.modelContainer {
                    await HabitLifecycle.logToday(habitID: habitID, in: container.mainContext)
                }
                completionHandler()
            }
            return
        }

        if identifier == "report-reminder" {
            Task { @MainActor in
                Self.pendingRoute = .habitOpenReportFromNotification
                NotificationCenter.default.post(name: .habitOpenReportFromNotification, object: nil)
            }
        }

        if identifier == "recap-reminder" {
            Task { @MainActor in
                Self.pendingRoute = .habitOpenRecapFromNotification
                NotificationCenter.default.post(name: .habitOpenRecapFromNotification, object: nil)
            }
        }

        if identifier.hasPrefix("timer-") {
            let uuidString = String(identifier.dropFirst("timer-".count))
            if let habitID = UUID(uuidString: uuidString) {
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: .habitOpenTimerFromNotification,
                        object: nil,
                        userInfo: ["habitID": habitID]
                    )
                }
            }
        }

        completionHandler()
    }
}
