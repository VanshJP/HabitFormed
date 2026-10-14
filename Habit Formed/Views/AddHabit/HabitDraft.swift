import Foundation

/// Everything the add and edit sheet can change, as one value. The sheet
/// edits a draft and writes it to the habit on Save, so Cancel never leaves a
/// half-edited habit behind and "has anything changed" is one comparison.
struct HabitDraft: Equatable {
    var title = ""
    var symbol = "circle.hexagongrid"
    var colorHex = AppColors.tilePalette.first?.hexString ?? "#0D8488"
    var kind: HabitTrackKind = .manual
    var frequency: HabitFrequency = .daily
    var weeklyTarget = 5
    var intervalDays = 3
    /// The health metric, read only when `kind` is `.health`.
    var source: HealthKitSource = .steps
    var targetValue: Double = HealthKitSource.steps.defaultTarget
    var timerDurationSeconds = 1500
    var reminderEnabled = false
    var reminderHour = 9
    var reminderMinute = 0
    /// New reminders follow the habit's usual log time by default.
    var reminderLearnsTime = true
    /// What the habit's logs have taught so far, read once when editing.
    private(set) var learnedReminderTime: ReminderTime?

    init() {}

    init(habit: Habit) {
        title = habit.title
        symbol = habit.symbol
        colorHex = habit.colorHex
        kind = habit.trackKind
        frequency = habit.frequency
        weeklyTarget = habit.weeklyTarget
        intervalDays = habit.intervalDays
        source = habit.source == .none ? .steps : habit.source
        targetValue = habit.source == .none ? source.defaultTarget : habit.targetValue
        timerDurationSeconds = habit.timerDurationSeconds > 0 ? habit.timerDurationSeconds : 1500
        reminderEnabled = habit.reminderEnabled
        reminderHour = habit.reminderHour
        reminderMinute = habit.reminderMinute
        // A habit without a reminder yet gets the learning default; one that
        // has a reminder keeps the choice already made.
        reminderLearnsTime = habit.reminderEnabled ? habit.reminderLearnsTime : true
        learnedReminderTime = habit.learnedReminderTime
    }

    /// The palette color the fewest habits wear, so each new habit starts
    /// in a color of its own without anyone picking one. Among those, the
    /// one farthest round the palette from the newest habit's, so the grid
    /// alternates hues instead of stepping teal to teal. `used` is every
    /// habit's color, oldest first.
    static func freshColor(after used: [String]) -> String {
        let palette = AppColors.tilePalette.map(\.hexString)
        guard !palette.isEmpty else { return "#0D8488" }
        let counts = Dictionary(used.map { ($0, 1) }, uniquingKeysWith: +)
        let fewest = palette.map { counts[$0, default: 0] }.min() ?? 0
        let open = palette.indices.filter { counts[palette[$0], default: 0] == fewest }
        guard let newest = used.last.flatMap({ palette.firstIndex(of: $0) }) else { return palette[open[0]] }
        func distance(_ index: Int) -> Int {
            let gap = abs(index - newest)
            return min(gap, palette.count - gap)
        }
        return palette[open.max { distance($0) < distance($1) } ?? open[0]]
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool { !trimmedTitle.isEmpty }

    // MARK: - Linked changes

    /// Interval is a manual-swipe cadence, so it snaps back to daily when the
    /// habit becomes timer- or HealthKit-tracked.
    mutating func setKind(_ new: HabitTrackKind) {
        kind = new
        if new != .manual && frequency == .interval {
            frequency = .daily
        }
        if new == .health {
            targetValue = frequency == .weekly ? source.weeklyDefaultTarget : source.defaultTarget
        }
    }

    mutating func setSource(_ new: HealthKitSource) {
        source = new
        targetValue = frequency == .weekly ? new.weeklyDefaultTarget : new.defaultTarget
    }

    /// Health targets snap to the cadence's sensible default (30 exercise
    /// minutes a day becomes 150 a week).
    mutating func setFrequency(_ new: HabitFrequency) {
        frequency = new
        if kind == .health {
            targetValue = new == .weekly ? source.weeklyDefaultTarget : source.defaultTarget
        }
    }

    mutating func apply(_ template: HabitTemplate) {
        title = template.title
        symbol = template.symbol
        colorHex = template.colorHex
        kind = template.kind
        frequency = template.frequency
        weeklyTarget = template.weeklyTarget
        intervalDays = template.intervalDays
        if let source = template.source {
            self.source = source
            targetValue = template.target ?? source.defaultTarget
        }
        if let seconds = template.timerSeconds {
            timerDurationSeconds = seconds
        }
    }

    // MARK: - Reminder time

    var reminderTime: Date {
        get {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date()
        }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = parts.hour ?? 9
            reminderMinute = parts.minute ?? 0
        }
    }

    // MARK: - Writing

    private var finalSource: HealthKitSource { kind == .health ? source : .none }
    private var finalTimer: Int { kind == .timer ? timerDurationSeconds : 0 }
    private var finalTarget: Double { kind == .health ? targetValue : 1 }

    func apply(to habit: Habit) {
        habit.title = trimmedTitle
        habit.symbol = symbol
        habit.colorHex = colorHex
        habit.frequencyRaw = frequency.rawValue
        habit.weeklyTarget = weeklyTarget
        habit.intervalDays = intervalDays
        habit.sourceRaw = finalSource.rawValue
        habit.targetValue = finalTarget
        habit.timerDurationSeconds = finalTimer
        habit.reminderEnabled = reminderEnabled
        habit.reminderHour = reminderHour
        habit.reminderMinute = reminderMinute
        habit.reminderLearnsTime = reminderLearnsTime
    }

    func makeHabit(sortOrder: Int) -> Habit {
        Habit(
            title: trimmedTitle,
            symbol: symbol,
            colorHex: colorHex,
            frequency: frequency,
            weeklyTarget: weeklyTarget,
            intervalDays: intervalDays,
            source: finalSource,
            targetValue: finalTarget,
            timerDurationSeconds: finalTimer,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            reminderLearnsTime: reminderLearnsTime,
            sortOrder: sortOrder
        )
    }
}

// MARK: - Templates

/// A ready-made habit: one tap fills the whole form.
nonisolated struct HabitTemplate: Identifiable, Sendable {
    let title: String
    let symbol: String
    let colorHex: String
    var kind: HabitTrackKind = .manual
    var frequency: HabitFrequency = .daily
    var weeklyTarget = 5
    var intervalDays = 3
    var source: HealthKitSource? = nil
    var target: Double? = nil
    var timerSeconds: Int? = nil

    var id: String { title }

    static let all: [HabitTemplate] = [
        HabitTemplate(title: "Read", symbol: "book.fill", colorHex: "#5966A6"),
        HabitTemplate(title: "Workout", symbol: "dumbbell.fill", colorHex: "#BF7866", frequency: .weekly, weeklyTarget: 4),
        HabitTemplate(title: "Meditate", symbol: "brain.head.profile", colorHex: "#739F80", kind: .timer, timerSeconds: 600),
        HabitTemplate(title: "Practice piano", symbol: "pianokeys", colorHex: "#8C5C84", kind: .timer, timerSeconds: 1800),
        HabitTemplate(title: "10k steps", symbol: "figure.walk", colorHex: "#2BA8A8", kind: .health, source: .steps, target: 10_000),
        HabitTemplate(title: "Sleep 7 hours", symbol: "bed.double.fill", colorHex: "#5B87C2", kind: .health, source: .sleepHours, target: 7),
        HabitTemplate(title: "Burn 500 kcal", symbol: "flame.fill", colorHex: "#BF9351", kind: .health, source: .activeCalories, target: 500),
        HabitTemplate(title: "Drink water", symbol: "drop.fill", colorHex: "#5B87C2"),
        HabitTemplate(title: "Journal", symbol: "pencil", colorHex: "#4C637E"),
        HabitTemplate(title: "Stretch", symbol: "figure.yoga", colorHex: "#739F80", kind: .timer, timerSeconds: 900),
        HabitTemplate(title: "Water the plants", symbol: "leaf.fill", colorHex: "#739F80", frequency: .interval, intervalDays: 3),
        HabitTemplate(title: "Call family", symbol: "phone.fill", colorHex: "#CC6B85", frequency: .weekly, weeklyTarget: 2),
        HabitTemplate(title: "Eat clean", symbol: "fork.knife", colorHex: "#BF9351"),
        HabitTemplate(title: "Study", symbol: "graduationcap.fill", colorHex: "#0D8488", kind: .timer, timerSeconds: 2700),
    ]
}
