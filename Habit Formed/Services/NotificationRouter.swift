import Foundation
import UserNotifications

extension Notification.Name {
    /// Posted when the user taps a timer completion alert; carries the
    /// habit UUID in `userInfo["habitID"]`.
    static let habitOpenTimerFromNotification = Notification.Name("habitOpenTimerFromNotification")
}

/// `UNUserNotificationCenterDelegate` attached at app launch.
///
/// Two jobs:
/// 1. Show banners even while the app is foregrounded (otherwise iOS
///    silently suppresses alerts the user is staring at).
/// 2. Route timer-alert taps into the app via
///    `Notification.Name.habitOpenTimerFromNotification` so `RootView`
///    can present that habit's timer sheet. Reminder taps just launch.
@MainActor
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
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
