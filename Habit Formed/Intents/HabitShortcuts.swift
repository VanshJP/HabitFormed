import AppIntents

/// What Siri, Spotlight and Shortcuts offer with no setup. Siri learns the
/// habit names from `updateAppShortcutParameters()`, which Today calls when
/// the habits change.
struct HabitShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogHabitTodayIntent(),
            phrases: [
                "Log \(\.$habit) in \(.applicationName)",
                "Mark \(\.$habit) done in \(.applicationName)",
                "I did \(\.$habit) in \(.applicationName)",
                "Check off \(\.$habit) in \(.applicationName)",
                "Log a habit in \(.applicationName)",
            ],
            shortTitle: "Log a habit",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: AddHabitIntent(),
            phrases: [
                "Add a habit in \(.applicationName)",
                "Add a habit to \(.applicationName)",
                "New habit in \(.applicationName)",
                "Create a habit in \(.applicationName)",
                "Start a habit in \(.applicationName)",
            ],
            shortTitle: "Add a habit",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: TodayStatusIntent(),
            phrases: [
                "What's left in \(.applicationName)",
                "What's left today in \(.applicationName)",
                "How's my day in \(.applicationName)",
            ],
            shortTitle: "What's left today",
            systemImageName: "list.bullet.circle"
        )
    }
}
