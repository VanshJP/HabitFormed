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
    /// Warm gray paper.
    case stone
    /// Cool blue-gray paper.
    case cloud

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
        case .stone: return "Stone"
        case .cloud: return "Cloud"
        case .black: return "Black"
        case .graphite: return "Graphite"
        case .navy: return "Navy"
        case .plum: return "Plum"
        case .forest: return "Forest"
        }
    }

    /// The canvas behind the card, or nil for the papers. `appLook` is the
    /// app's current one, used by `.app`.
    func look(appLook: CanvasLook) -> CanvasLook? {
        switch self {
        case .app: return appLook
        case .classic: return .classic
        case .midnight: return .midnight
        case .aurora: return .aurora
        case .ember: return .ember
        case .dusk: return .dusk
        case .tide: return .tide
        case .paper, .stone, .cloud: return nil
        case .black: return .black
        case .graphite: return .graphite
        case .navy: return .navy
        case .plum: return .plum
        case .forest: return .forest
        }
    }

    /// True for the light themes, which print on paper.
    var isPaper: Bool { self == .paper || self == .stone || self == .cloud }
}

// MARK: - Report Scope

/// Which card the report sheet makes: the day, the last seven days, or the
/// year so far. Not stored: each way in opens on its own.
nonisolated enum ReportScope: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .year: return "Year"
        }
    }
}

// MARK: - Year Layout

/// How the year card draws its days. Persisted by raw value
/// (`AppPreferences.reportYearLayout`).
nonisolated enum YearLayout: String, CaseIterable, Identifiable, Sendable {
    /// A row per month, a square per day: the year in pixels.
    case pixels
    /// Twelve small month calendars, four to a row.
    case months

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pixels: return "Pixels"
        case .months: return "Months"
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
    /// A board of the last seven days, a row per habit.
    case week
    /// The last seven days as rings, one per habit, from the outside in.
    case rings
    /// One big ring and a strip of glyphs: the day at a glance.
    case focus
    /// The day's ring with each habit on an orbit round it.
    case orbit
    /// A 24-hour dial: each log at its time, sleep and workouts as bands.
    case sundial
    /// A plant per habit: a leaf per day of its run, a bloom once done.
    case garden
    /// A night sky: each done habit a star, joined in the order logged.
    case constellation
    /// A circle per habit in a honeycomb, filled once done.
    case bubbles
    /// The day as a newspaper's front page, its headline written from it.
    case frontPage
    /// A loyalty card: a row per habit, a hole punched per day done.
    case punchCard
    /// A stamp per habit on an airmail envelope, postmarked once done.
    case stamps
    /// A paper slip: a line per habit, the day's totals and a barcode.
    case receipt
    /// A table: a row per habit, today, the run and the week in columns.
    case ledger
    /// The day in the order it was logged, each log at its time.
    case timeline
    /// The count set large and the habits under it in two columns.
    case minimal

    var id: String { rawValue }

    /// The order the editor offers them: the plain, professional ones
    /// first, then the charts, then the things of their own.
    static let gallery: [ReportLayout] = [
        .list, .ledger, .minimal, .timeline, .grid, .week,
        .rings, .focus, .orbit, .sundial, .bubbles, .garden,
        .frontPage, .receipt, .punchCard, .stamps, .constellation,
    ]

    var title: String {
        switch self {
        case .list: return "List"
        case .grid: return "Grid"
        case .focus: return "Focus"
        case .week: return "Week"
        case .rings: return "Rings"
        case .orbit: return "Orbit"
        case .sundial: return "Sundial"
        case .garden: return "Garden"
        case .constellation: return "Constellation"
        case .frontPage: return "Front page"
        case .punchCard: return "Punch card"
        case .stamps: return "Stamps"
        case .bubbles: return "Bubbles"
        case .receipt: return "Receipt"
        case .ledger: return "Ledger"
        case .timeline: return "Timeline"
        case .minimal: return "Minimal"
        }
    }

    /// Each habit's note needs a row to sit under: List and Timeline.
    var showsHabitNotes: Bool { self == .list || self == .timeline }

    /// The last seven days as dots in a row: List and Ledger.
    var showsWeekDots: Bool { self == .list || self == .ledger }

    /// Focus and Orbit stand alone as one poster under a centred header.
    var isPoster: Bool { self == .focus || self == .orbit }

    /// The layouts that are a thing of their own (a front page, a punch card,
    /// a night sky, an envelope, a receipt): the whole image, with their own
    /// paper, ink and type, so the card's accent and type do not reach them.
    /// The receipt is a slip lying on the card's background, so that still
    /// reaches it.
    var ownsLook: Bool {
        switch self {
        case .frontPage, .punchCard, .constellation, .stamps, .receipt: return true
        default: return false
        }
    }

    /// The card's background shows: every layout but the ones that bring
    /// their own paper edge to edge.
    var showsBackground: Bool { !ownsLook || self == .receipt }

    /// The layouts with the day's count in the header's corner, which
    /// `ReportRing` sizes or turns into a number. Focus and Orbit are their
    /// ring, Rings, Sundial and Minimal count the day in their middle, and
    /// the layouts with a look of their own print it their way.
    var showsRing: Bool {
        !isPoster && !ownsLook && self != .rings && self != .sundial && self != .minimal
    }
}

// MARK: - Report Ring

/// How the header counts the day. Persisted by raw value
/// (`AppPreferences.reportRing`); the names are older than the choices.
nonisolated enum ReportRing: String, CaseIterable, Identifiable, Sendable {
    /// A big ring in the header's corner.
    case big
    /// A small ring in the header's corner.
    case corner
    /// No ring: the count as a number.
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .big: return "Big ring"
        case .corner: return "Small ring"
        case .off: return "Number"
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
    var yearLayout: YearLayout = .pixels
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

    /// The note for this card, trimmed; empty when there is none.
    var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// These options with another layout, for the layout gallery.
    func with(layout: ReportLayout) -> ReportOptions {
        var copy = self
        copy.layout = layout
        return copy
    }

    func with(yearLayout: YearLayout) -> ReportOptions {
        var copy = self
        copy.yearLayout = yearLayout
        return copy
    }

    /// The look alone, so typing a note does not count as a new look.
    var style: ReportOptions {
        var copy = self
        copy.note = ""
        return copy
    }

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
