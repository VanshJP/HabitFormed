import Foundation
import SwiftData

// MARK: - Report Style

/// The layout a daily report card is drawn in. Persisted by raw value
/// (`ReportTemplate.styleRaw`); do not rename existing cases.
nonisolated enum ReportStyle: String, CaseIterable, Identifiable, Sendable {
    /// A progress ring over a checklist. The everyday report.
    case scoreboard
    /// A paper till receipt: habits as line items, a total, calories as tax.
    case receipt
    /// Calories in against calories out first, habits under it.
    case fuel
    /// An accountability check-in: a plain done / not done list and a promise.
    case checkIn
    /// The perfect-day streak as a poster, with today's count under it.
    case streak
    /// White paper, ink type, nothing else.
    case clean

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .scoreboard: return "Scoreboard"
        case .receipt: return "Receipt"
        case .fuel: return "Fuel"
        case .checkIn: return "Check-in"
        case .streak: return "Streak"
        case .clean: return "Clean"
        }
    }

    var symbol: String {
        switch self {
        case .scoreboard: return "circle.dashed.inset.filled"
        case .receipt: return "scroll"
        case .fuel: return "fork.knife"
        case .checkIn: return "checklist"
        case .streak: return "flame"
        case .clean: return "doc.plaintext"
        }
    }

    var summary: String {
        switch self {
        case .scoreboard: return "A ring and your checklist"
        case .receipt: return "Habits itemised like a till receipt"
        case .fuel: return "Calories in vs out, then habits"
        case .checkIn: return "Done and not done, for a buddy"
        case .streak: return "Your perfect-day run, poster size"
        case .clean: return "Plain paper, nothing extra"
        }
    }

    /// Paper styles draw their own light page, so the background picker is
    /// hidden for them.
    var isPaper: Bool { self == .receipt || self == .clean }
}

// MARK: - Report Theme

/// The canvas behind a dark report card: the app's own looks, at poster
/// intensity. Persisted by raw value (`ReportTemplate.themeRaw`).
nonisolated enum ReportTheme: String, CaseIterable, Identifiable, Sendable {
    case classic
    case midnight
    case aurora
    case ember
    case dusk
    case tide
    case depth
    case mist
    case noir

    var id: String { rawValue }

    var look: CanvasLook {
        switch self {
        case .classic: return .classic
        case .midnight: return .midnight
        case .aurora: return .aurora
        case .ember: return .ember
        case .dusk: return .dusk
        case .tide: return .tide
        case .depth: return .depth
        case .mist: return .mist
        case .noir: return .noir
        }
    }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .midnight: return "Midnight"
        case .aurora: return "Aurora"
        case .ember: return "Ember"
        case .dusk: return "Dusk"
        case .tide: return "Tide"
        case .depth: return "Depth"
        case .mist: return "Mist"
        case .noir: return "Noir"
        }
    }
}

// MARK: - Report Template

/// One saved way of reporting a day: its layout, its words and what it
/// includes. Users keep several (a calorie check for one friend, a check-in
/// for another) and pick one each time they send.
///
/// Every field has a default so SwiftData lightweight migration can add new
/// ones later. Enums persist as `String` raw values.
@Model
final class ReportTemplate {
    var id: UUID = UUID()
    /// What the template is called in the picker. Never on the card.
    var name: String = "Daily report"
    var createdAt: Date = Date()
    var sortOrder: Int = 0

    var styleRaw: String = ReportStyle.scoreboard.rawValue
    var themeRaw: String = ReportTheme.classic.rawValue
    var accentHex: String = "#2BA8A8"

    // MARK: Words (tokens like {done} expand at send time)

    /// The card's headline.
    var title: String = "Daily report"
    /// One line under the content: a promise, a quote, a dare.
    var message: String = ""
    /// The small line at the foot of the card.
    var footer: String = ""
    /// The text message sent with the card. Empty means the standard summary.
    var caption: String = ""

    // MARK: What to include

    var includeAllHabits: Bool = true
    /// Comma-joined habit UUIDs, read when `includeAllHabits` is false.
    var selectedHabitIDsRaw: String = ""
    /// Lists habits that are not done yet. Off is "wins only".
    var showUnfinished: Bool = true
    var showStreaks: Bool = true
    var showWeek: Bool = false
    var showNotes: Bool = true
    var showPerfectStreak: Bool = true
    var showCalories: Bool = false
    /// Daily calorie budget for the fuel line. Zero hides the goal.
    var calorieGoal: Double = 2000
    var showActivity: Bool = false
    /// Sends the caption text alongside the card image.
    var attachCaption: Bool = true

    init(name: String = "Daily report", sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    // MARK: - Computed

    var style: ReportStyle {
        get { ReportStyle(rawValue: styleRaw) ?? .scoreboard }
        set { styleRaw = newValue.rawValue }
    }

    var theme: ReportTheme {
        get { ReportTheme(rawValue: themeRaw) ?? .classic }
        set { themeRaw = newValue.rawValue }
    }

    var selectedHabitIDs: Set<UUID> {
        get {
            Set(selectedHabitIDsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        }
        set {
            selectedHabitIDsRaw = newValue.map(\.uuidString).sorted().joined(separator: ",")
        }
    }

    /// A value copy for rendering and text, safe to hand to pure code.
    var content: ReportContent {
        ReportContent(
            style: style,
            theme: theme,
            accentHex: accentHex,
            title: title,
            message: message,
            footer: footer,
            caption: caption,
            includeAllHabits: includeAllHabits,
            selectedHabitIDs: selectedHabitIDs,
            showUnfinished: showUnfinished,
            showStreaks: showStreaks,
            showWeek: showWeek,
            showNotes: showNotes,
            showPerfectStreak: showPerfectStreak,
            showCalories: showCalories,
            calorieGoal: calorieGoal,
            showActivity: showActivity,
            attachCaption: attachCaption
        )
    }

    /// Copies every setting from `preset`.
    func apply(_ preset: ReportPreset) {
        name = preset.name
        style = preset.style
        theme = preset.theme
        accentHex = preset.accentHex
        title = preset.title
        message = preset.message
        footer = preset.footer
        caption = preset.caption
        showUnfinished = preset.showUnfinished
        showStreaks = preset.showStreaks
        showWeek = preset.showWeek
        showNotes = preset.showNotes
        showPerfectStreak = preset.showPerfectStreak
        showCalories = preset.showCalories
        calorieGoal = preset.calorieGoal
        showActivity = preset.showActivity
    }

    /// Copies every setting from another template, for Duplicate.
    func copySettings(from other: ReportTemplate) {
        styleRaw = other.styleRaw
        themeRaw = other.themeRaw
        accentHex = other.accentHex
        title = other.title
        message = other.message
        footer = other.footer
        caption = other.caption
        includeAllHabits = other.includeAllHabits
        selectedHabitIDsRaw = other.selectedHabitIDsRaw
        showUnfinished = other.showUnfinished
        showStreaks = other.showStreaks
        showWeek = other.showWeek
        showNotes = other.showNotes
        showPerfectStreak = other.showPerfectStreak
        showCalories = other.showCalories
        calorieGoal = other.calorieGoal
        showActivity = other.showActivity
        attachCaption = other.attachCaption
    }
}

// MARK: - Report Content

/// A template's settings as a plain value, so the card, the caption and the
/// token expander never touch a SwiftData model.
nonisolated struct ReportContent: Sendable, Hashable {
    var style: ReportStyle
    var theme: ReportTheme
    var accentHex: String
    var title: String
    var message: String
    var footer: String
    var caption: String
    var includeAllHabits: Bool
    var selectedHabitIDs: Set<UUID>
    var showUnfinished: Bool
    var showStreaks: Bool
    var showWeek: Bool
    var showNotes: Bool
    var showPerfectStreak: Bool
    var showCalories: Bool
    var calorieGoal: Double
    var showActivity: Bool
    var attachCaption: Bool

    /// True when the card needs Apple Health numbers.
    var needsHealth: Bool { showCalories || showActivity || style == .fuel }
}

// MARK: - Presets

/// A starting point for a template. The report sheet seeds one template per
/// preset the first time it opens; New offers the list again.
nonisolated struct ReportPreset: Identifiable, Sendable {
    let id: String
    let name: String
    let blurb: String
    let style: ReportStyle
    let theme: ReportTheme
    let accentHex: String
    let title: String
    let message: String
    let footer: String
    let caption: String
    var showUnfinished = true
    var showStreaks = true
    var showWeek = false
    var showNotes = true
    var showPerfectStreak = true
    var showCalories = false
    var calorieGoal: Double = 2000
    var showActivity = false

    static let all: [ReportPreset] = [
        ReportPreset(
            id: "scoreboard",
            name: "Daily scoreboard",
            blurb: "Ring, checklist and streaks",
            style: .scoreboard,
            theme: .classic,
            accentHex: "#2BA8A8",
            title: "Daily report",
            message: "",
            footer: "Tracked with Habit Formed",
            caption: "{name} · {date}\n{done} of {total} done ({percent})\n{checklist}",
            showWeek: true
        ),
        ReportPreset(
            id: "receipt",
            name: "Receipt",
            blurb: "Habits itemised like a till receipt",
            style: .receipt,
            theme: .classic,
            accentHex: "#121214",
            title: "Habit Formed",
            message: "No refunds on effort.",
            footer: "Thank you for showing up",
            caption: "Today's receipt: {done}/{total} habits paid in full.\n{checklist}",
            showStreaks: false,
            showCalories: true
        ),
        ReportPreset(
            id: "fuel",
            name: "Calorie check",
            blurb: "Eaten vs burned, then habits",
            style: .fuel,
            theme: .ember,
            accentHex: "#F5A93C",
            title: "Fuel report",
            message: "",
            footer: "Calories from Apple Health",
            caption: "Fuel report for {day}: {eaten} eaten, {burned} burned, {net} net (goal {goal}).\n{checklist}",
            showStreaks: false,
            showCalories: true,
            calorieGoal: 2000,
            showActivity: true
        ),
        ReportPreset(
            id: "checkin",
            name: "Accountability",
            blurb: "Done and not done, for a buddy",
            style: .checkIn,
            theme: .midnight,
            accentHex: "#38CC80",
            title: "Check-in",
            message: "Hold me to it.",
            footer: "",
            caption: "Check-in for {day}: {done} of {total} done, {left} to go.\n{checklist}\nHold me to it.",
            showNotes: true
        ),
        ReportPreset(
            id: "streak",
            name: "Streak flex",
            blurb: "Your perfect-day run, poster size",
            style: .streak,
            theme: .dusk,
            accentHex: "#F5A93C",
            title: "Not missing a day",
            message: "",
            footer: "Tracked with Habit Formed",
            caption: "{streak} perfect days in a row. {done}/{total} today and counting.",
            showUnfinished: false,
            showStreaks: false
        ),
        ReportPreset(
            id: "wins",
            name: "Wins only",
            blurb: "Just what got done today",
            style: .scoreboard,
            theme: .aurora,
            accentHex: "#4DEBC7",
            title: "Today's wins",
            message: "",
            footer: "Tracked with Habit Formed",
            caption: "Today's wins:\n{checklist}",
            showUnfinished: false
        ),
        ReportPreset(
            id: "clean",
            name: "Clean",
            blurb: "Plain paper, nothing extra",
            style: .clean,
            theme: .classic,
            accentHex: "#0D8488",
            title: "{day}",
            message: "",
            footer: "",
            caption: "{done}/{total} habits on {day}.\n{checklist}",
            showStreaks: false,
            showPerfectStreak: false
        ),
    ]
}

extension ReportTemplate {
    /// A new template filled from `preset`. Not inserted; the caller owns that.
    static func make(from preset: ReportPreset, sortOrder: Int) -> ReportTemplate {
        let template = ReportTemplate(name: preset.name, sortOrder: sortOrder)
        template.apply(preset)
        return template
    }
}
