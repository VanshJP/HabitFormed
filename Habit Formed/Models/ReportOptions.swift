import Foundation

// MARK: - Report Theme

/// The look of the daily report card: one of the app's canvases, or paper.
/// Persisted by raw value (`AppPreferences.reportTheme`); do not rename cases.
nonisolated enum ReportTheme: String, CaseIterable, Identifiable, Sendable {
    case classic
    case midnight
    case aurora
    case ember
    case dusk
    case tide
    case paper

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .midnight: return "Midnight"
        case .aurora: return "Aurora"
        case .ember: return "Ember"
        case .dusk: return "Dusk"
        case .tide: return "Tide"
        case .paper: return "Paper"
        }
    }

    /// The canvas behind the card, or nil for paper.
    var look: CanvasLook? {
        switch self {
        case .classic: return .classic
        case .midnight: return .midnight
        case .aurora: return .aurora
        case .ember: return .ember
        case .dusk: return .dusk
        case .tide: return .tide
        case .paper: return nil
        }
    }
}

// MARK: - Report Options

/// What the daily report shows. One report, everything on by default; the
/// switches take things out. The sheet keeps these in `@AppStorage` so the
/// next report starts the way the last one was sent.
nonisolated struct ReportOptions: Sendable, Hashable {
    var theme: ReportTheme = .classic
    /// Habits left off the card.
    var hiddenHabitIDs: Set<UUID> = []
    var showStreaks = true
    var showNotes = true
    var showWeek = true
    var showCalories = false
    var showActivity = false
    /// A line for this card only ("Rest day tomorrow"). Not kept.
    var note = ""

    /// True when the card needs Apple Health numbers.
    var needsHealth: Bool { showCalories || showActivity }

    /// Hidden habit IDs as stored: comma-joined UUID strings.
    static func hiddenIDs(from raw: String) -> Set<UUID> {
        Set(raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    static func raw(from ids: Set<UUID>) -> String {
        ids.map(\.uuidString).sorted().joined(separator: ",")
    }
}
