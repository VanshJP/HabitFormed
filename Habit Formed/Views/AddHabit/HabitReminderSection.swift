import SwiftUI

/// One reminder per habit. By default it learns: once a few logs exist it
/// fires `ReminderTiming.leadMinutes` before the habit is usually logged, and
/// the set time covers the days before that. A new habit gets a time from its
/// name and the person's routine (`ReminderSuggestion`), with the reason as a
/// caption, and the time follows the name until the picker is moved.
/// Permission is asked the moment the switch turns on, never at launch.
struct HabitReminderSection: View {
    @Binding var draft: HabitDraft
    /// Other habits' titles and usual log minutes. Nil when editing, so a
    /// time already set never moves.
    let routine: [(title: String, minute: Int)]?
    @Environment(NotificationService.self) private var notifications

    @State private var pickedTime = false
    /// The model's wording of the suggestion, with the name it was for.
    @State private var phrased: (title: String, text: String)?

    var body: some View {
        Panel {
            SettingsRow("Remind me", icon: "bell", caption: draft.reminderEnabled && canLearn ? nil : explanation, isOn: $draft.reminderEnabled)
            if draft.reminderEnabled {
                SettingsRow("Time", icon: "clock") {
                    if let learned = shownLearnedTime {
                        Text(learned.label)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        DatePicker("Reminder time", selection: pickerTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
                if canLearn {
                    SettingsRow("Match my routine", icon: "sparkles", caption: learnCaption, isOn: $draft.reminderLearnsTime)
                }
            }
        }
        .motion(AppMotion.settle, value: draft.reminderEnabled)
        .motion(AppMotion.settle, value: draft.reminderLearnsTime)
        .onChange(of: draft.reminderEnabled) { _, isOn in
            // iOS silently denies repeat prompts after a refusal, so ask at
            // the moment of intent.
            if isOn && !notifications.isAuthorized {
                Task { await notifications.requestAuthorization() }
            }
            followSuggestion()
        }
        .onChange(of: suggestion) { followSuggestion() }
        .task(id: draft.trimmedTitle) { await phrase() }
    }

    /// Health habits log themselves from Apple Health, so their log times say
    /// nothing about the person's routine.
    private var canLearn: Bool { draft.kind != .health }

    private var shownLearnedTime: ReminderTime? {
        canLearn && draft.reminderLearnsTime ? draft.learnedReminderTime : nil
    }

    private var suggestion: ReminderSuggestion? {
        routine.flatMap { ReminderSuggestion.suggest(for: draft.title, routine: $0) }
    }

    /// Moving the picker makes the time the person's own.
    private var pickerTime: Binding<Date> {
        Binding(get: { draft.reminderTime }, set: { draft.reminderTime = $0; pickedTime = true })
    }

    /// Only written while the switch is on, so an untouched form stays clean.
    private func followSuggestion() {
        guard draft.reminderEnabled, !pickedTime, let time = suggestion?.time else { return }
        draft.reminderHour = time.hour
        draft.reminderMinute = time.minute
    }

    /// "9:30 PM, evenings suit reading", while the suggestion sets the time
    /// (or would, once on). The model's wording when it has one for this name.
    private var explanation: String? {
        guard let suggestion, !(draft.reminderEnabled && pickedTime) else { return nil }
        if let phrased, phrased.title == draft.trimmedTitle { return phrased.text }
        return "\(suggestion.time.label), \(suggestion.reason.prefix(1).lowercased())\(suggestion.reason.dropFirst())"
    }

    private var learnCaption: String {
        let rule: String
        if !draft.reminderLearnsTime {
            rule = "Always at this time"
        } else if let usual = draft.usualLogMinute {
            rule = "You usually log around \(ReminderTime(minuteOfDay: usual).label)"
        } else {
            rule = "After \(ReminderTiming.minimumLogs) logs, \(ReminderTiming.leadMinutes) min before you usually log"
        }
        return explanation.map { "\($0). \(rule)" } ?? rule
    }

    /// Words the suggestion with the on-device model once typing pauses, and
    /// keeps the reply only if it still names the suggested time.
    private func phrase() async {
        let title = draft.trimmedTitle
        guard let suggestion, (try? await Task.sleep(for: .milliseconds(600))) != nil else { return }
        // Times format with a narrow space before AM or PM; the model types a plain one.
        let time = suggestion.time.label.replacingOccurrences(of: "\u{202F}", with: " ")
        let reply = await OnDeviceModel.phrase(
            "Habit: \(title). Reminder: \(time). Why: \(suggestion.reason).",
            instructions: "Say why a habit's reminder is at its time, in one plain sentence under 50 characters. Keep the time exactly as given. No em dashes."
        )
        guard !Task.isCancelled,
              let text = reply?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              text.count <= 60,
              text.replacingOccurrences(of: "\u{202F}", with: " ").contains(time)
        else { return }
        phrased = (title, text)
    }
}
