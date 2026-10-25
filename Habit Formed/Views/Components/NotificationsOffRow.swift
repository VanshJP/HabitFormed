import SwiftUI

/// Under a reminder switch that is on while iOS has the app's notifications
/// turned off, so the switch never fails quietly. Opens the app's
/// notification settings.
struct NotificationsOffRow: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            Haptics.light()
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
        } label: {
            SettingsRow("Notifications are off", icon: "bell.slash", caption: "Allow them in Settings to get reminders", trailing: .external)
        }
        .buttonStyle(RowPressStyle())
    }
}
