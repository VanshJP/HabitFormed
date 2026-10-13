import Foundation

/// `UserDefaults` keys for app preferences. Preferences only: habit data
/// lives in SwiftData.
nonisolated enum AppPreferences {
    /// `AppCanvas` raw value behind every screen.
    static let appCanvas = "pref.appCanvas"
    /// `GlassAppearance` raw value.
    static let glassAppearance = "pref.glassAppearance"
    /// Plays the chime when a habit is logged. Defaults to on.
    static let logSound = "pref.logSound"
    /// The name printed on daily report cards so a forwarded card still says
    /// whose day it was.
    static let reporterName = "report.name"
    /// Daily report choices, kept so the next report starts the same way.
    static let reportTheme = "report.theme"
    static let reportHiddenHabits = "report.hiddenHabits"
    static let reportShowStreaks = "report.showStreaks"
    static let reportShowNotes = "report.showNotes"
    static let reportShowWeek = "report.showWeek"
    static let reportShowCalories = "report.showCalories"
    static let reportShowActivity = "report.showActivity"
    /// Evening nudge to send the day's report.
    static let reportReminderEnabled = "report.reminder.enabled"
    static let reportReminderHour = "report.reminder.hour"
    static let reportReminderMinute = "report.reminder.minute"

    static var isLogSoundOn: Bool {
        UserDefaults.standard.object(forKey: logSound) as? Bool ?? true
    }
}
