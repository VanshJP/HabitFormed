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
    /// A board of the last seven days, a row per habit.
    case week
    /// A circle per habit in a honeycomb, filled once done.
    case bubbles
    /// A paper slip: a line per habit, the day's totals and a barcode.
    case receipt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: return "List"
        case .grid: return "Grid"
        case .focus: return "Focus"
        case .week: return "Week"
        case .bubbles: return "Bubbles"
        case .receipt: return "Receipt"
        }
    }

    /// Notes and the week's dots need a row to sit in.
    var showsRowDetail: Bool { self == .list }

    /// The layouts with a ring beside the verdict, which `ReportRing` can
    /// shrink to the corner or leave off. Focus is its ring, and the
    /// receipt prints the count.
    var showsRing: Bool { self != .focus && self != .receipt }
}

// MARK: - Report Ring

/// Where the card's progress ring sits. Persisted by raw value
/// (`AppPreferences.reportRing`).
nonisolated enum ReportRing: String, CaseIterable, Identifiable, Sendable {
    /// Big beside the verdict.
    case big
    /// Small in the header's top corner, so the card is shorter.
    case corner
    /// No ring: the verdict and the day's share say it in words.
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .big: return "Big"
        case .corner: return "Corner"
        case .off: return "Off"
        }
    }
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

// MARK: - Report Metric

/// One Apple Health number the card can carry, each switched on by itself so
/// what is picked is exactly what shows. Persisted by raw value in
/// `AppPreferences.reportMetrics`; do not rename cases.
nonisolated enum ReportMetric: String, CaseIterable, Identifiable, Sendable {
    case steps
    case exercise
    case sleep
    case mindful
    /// Eaten, burned and the difference.
    case calories
    /// Protein, carbs and fat in grams.
    case macros

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steps: return "Steps"
        case .exercise: return "Exercise"
        case .sleep: return "Sleep"
        case .mindful: return "Mindful"
        case .calories: return "Calories"
        case .macros: return "Macros"
        }
    }

    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .exercise: return "figure.run"
        case .sleep: return "bed.double.fill"
        case .mindful: return "brain.head.profile"
        case .calories: return "fork.knife"
        case .macros: return "chart.pie"
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
    var ring: ReportRing = .big
    /// A palette colour's hex for the ring, mark and note bar, or empty to
    /// follow the theme's own accent.
    var accentHex = ""
    var font: ReportFont = .standard
    /// Habits left off the card.
    var hiddenHabitIDs: Set<UUID> = []
    var showStreaks = true
    var showNotes = true
    var showWeek = true
    /// The Apple Health numbers on the card. None until picked.
    var metrics: Set<ReportMetric> = []
    /// A line for this card only ("Rest day tomorrow"). Not kept.
    var note = ""

    /// The canvas behind the card, or nil for paper.
    var look: CanvasLook? { theme.look(appLook: appLook) }

    /// True when the card needs Apple Health numbers.
    var needsHealth: Bool { !metrics.isEmpty }

    func shows(_ metric: ReportMetric) -> Bool { metrics.contains(metric) }

    /// Hidden habit IDs as stored: comma-joined UUID strings.
    static func hiddenIDs(from raw: String) -> Set<UUID> {
        Set(raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    static func raw(from ids: Set<UUID>) -> String {
        ids.map(\.uuidString).sorted().joined(separator: ",")
    }

    /// Metrics as stored: comma-joined raw values.
    static func metrics(from raw: String) -> Set<ReportMetric> {
        Set(raw.split(separator: ",").compactMap { ReportMetric(rawValue: String($0)) })
    }

    static func raw(from metrics: Set<ReportMetric>) -> String {
        ReportMetric.allCases.filter { metrics.contains($0) }.map(\.rawValue).joined(separator: ",")
    }

    /// The stored metrics' default until one is picked: what the old
    /// Calories and Activity switches had on, so an upgrade keeps the card.
    static var legacyMetricsRaw: String {
        let defaults = UserDefaults.standard
        var metrics: Set<ReportMetric> = []
        if defaults.bool(forKey: AppPreferences.reportShowCalories) { metrics.insert(.calories) }
        if defaults.bool(forKey: AppPreferences.reportShowActivity) {
            metrics.formUnion([.steps, .exercise, .sleep, .mindful])
        }
        return raw(from: metrics)
    }
}
