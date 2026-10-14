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
    /// `TodayLayout` raw value: tiles or rows.
    static let todayLayout = "pref.todayLayout"
    /// The name printed on daily report cards so a forwarded card still says
    /// whose day it was.
    static let reporterName = "report.name"
    /// Daily report choices, kept so the next report starts the same way.
    static let reportTheme = "report.theme"
    static let reportLayout = "report.layout"
    /// A palette hex, or empty to follow the theme.
    static let reportAccent = "report.accent"
    static let reportFont = "report.font"
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
    /// Sunday evening nudge to send the week's recap.
    static let recapReminderEnabled = "recap.reminder.enabled"
    /// History's Apple Intelligence tip, and the day and facts it was worded
    /// for, so the model runs once a day per set of facts.
    static let insightsTip = "insights.tip"
    static let insightsTipSource = "insights.tip.source"

    static var isLogSoundOn: Bool {
        UserDefaults.standard.object(forKey: logSound) as? Bool ?? true
    }
}

/// How Today lays out its habits.
nonisolated enum TodayLayout: String, CaseIterable, Identifiable, Sendable {
    /// The two-column grid of tiles.
    case tiles
    /// One compact row per habit, so more fit on screen.
    case rows

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tiles: return "Tiles"
        case .rows: return "Rows"
        }
    }

    var icon: String {
        switch self {
        case .tiles: return "square.grid.2x2"
        case .rows: return "list.bullet"
        }
    }
}
