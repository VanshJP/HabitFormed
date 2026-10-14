import Foundation

// MARK: - Report Theme

/// The look of the daily report card: the app's own look (the default), one
/// of the canvases, or paper. Persisted by raw value
/// (`AppPreferences.reportTheme`); do not rename cases.
nonisolated enum ReportTheme: String, CaseIterable, Identifiable, Sendable {
    /// Whatever the app wears (`AppCanvas`), so the card matches without a
    /// second choice.
    case app
    case classic
    // The plain ones up front, as on the app's look rail.
    case black
    case graphite
    case navy
    case plum
    case forest
    case midnight
    case aurora
    case ember
    case dusk
    case tide
    case paper

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .app: return "App look"
        case .classic: return "Classic"
        case .midnight: return "Midnight"
        case .aurora: return "Aurora"
        case .ember: return "Ember"
        case .dusk: return "Dusk"
        case .tide: return "Tide"
        case .paper: return "Paper"
        case .black: return "Black"
        case .graphite: return "Graphite"
        case .navy: return "Navy"
        case .plum: return "Plum"
        case .forest: return "Forest"
        }
    }

    /// The canvas behind the card, or nil for paper. `appLook` is the app's
    /// current one, used by `.app`.
    func look(appLook: CanvasLook) -> CanvasLook? {
        switch self {
        case .app: return appLook
        case .classic: return .classic
        case .midnight: return .midnight
        case .aurora: return .aurora
        case .ember: return .ember
        case .dusk: return .dusk
        case .tide: return .tide
        case .paper: return nil
        case .black: return .black
        case .graphite: return .graphite
        case .navy: return .navy
        case .plum: return .plum
        case .forest: return .forest
        }
    }
}

// MARK: - Report Layout

/// How the card lays out the habits. Persisted by raw value
/// (`AppPreferences.reportLayout`).
nonisolated enum ReportLayout: String, CaseIterable, Identifiable, Sendable {
    /// A row per habit with its detail, streak, note and week.
    case list
    /// A square per habit, filled with its colour once done, like Today.
    case grid
    /// One big ring and a strip of glyphs: the day at a glance.
    case focus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: return "List"
        case .grid: return "Grid"
        case .focus: return "Focus"
        }
    }

    /// Notes and the week's dots need a row to sit in.
    var showsRowDetail: Bool { self == .list }
}

// MARK: - Report Font

/// The card's typeface family. Persisted by raw value
/// (`AppPreferences.reportFont`).
nonisolated enum ReportFont: String, CaseIterable, Identifiable, Sendable {
    case standard
    case rounded
    case serif
    case mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Default"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .mono: return "Mono"
        }
    }
}

// MARK: - Report Options

/// What the daily report shows and how it looks. One report, everything on
/// by default; the switches take things out. Kept in `@AppStorage`, set in
/// Settings → Report card or the sheet's Edit, so sending needs no choices.
nonisolated struct ReportOptions: Sendable, Hashable {
    var theme: ReportTheme = .app
    /// The app's look, which `.app` paints.
    var appLook: CanvasLook = .classic
    var layout: ReportLayout = .list
    /// A palette colour's hex for the ring, mark and note bar, or empty to
    /// follow the theme's own accent.
    var accentHex = ""
    var font: ReportFont = .standard
    /// Habits left off the card.
    var hiddenHabitIDs: Set<UUID> = []
    var showStreaks = true
    var showNotes = true
    var showWeek = true
    var showCalories = false
    var showActivity = false
    /// A line for this card only ("Rest day tomorrow"). Not kept.
    var note = ""

    /// The canvas behind the card, or nil for paper.
    var look: CanvasLook? { theme.look(appLook: appLook) }

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
