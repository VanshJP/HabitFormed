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
            if draft.reminderEnabled && notifications.isDenied {
                NotificationsOffRow()
            }
            if draft.reminderEnabled && draft.frequency != .interval {
                VStack(spacing: 0) {
                    SettingsRow("Days", icon: "calendar", caption: daysCaption)
                    ReminderDaysPicker(days: $draft.reminderWeekdays)
                        .padding(.horizontal, AppLayout.tilePadding)
                        .padding(.bottom, 6)
                }
            }
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

    /// What no picked days means; a weekly habit's reminder still goes quiet
    /// once the week is done.
    private var daysCaption: String? {
        guard draft.reminderWeekdays.isEmpty else { return nil }
        return draft.frequency == .weekly ? "Every day until the week is done" : "Every day"
    }

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

    /// Why the suggested time, while the suggestion sets it (or would, once
    /// on). The model's wording when it has one for this name.
    private var reason: String? {
        guard let suggestion, !(draft.reminderEnabled && pickedTime) else { return nil }
        if let phrased, phrased.title == draft.trimmedTitle { return phrased.text }
        return suggestion.reason
    }

    /// "9:30 PM, evenings suit reading" while off; the Time row shows the
    /// time once on, so the caption then gives only the reason.
    private var explanation: String? {
        guard let reason, let suggestion else { return nil }
        if draft.reminderEnabled { return reason }
        return "\(suggestion.time.label), \(reason.prefix(1).lowercased())\(reason.dropFirst())"
    }

    private var learnCaption: String {
        let rule: String
        if !draft.reminderLearnsTime {
            rule = "Always at this time"
        } else if let usual = draft.usualLogMinute {
            rule = "You usually log around \(ReminderTime(minuteOfDay: usual).label)"
        } else {
            rule = "After \(ReminderTiming.minimumLogs) logs it moves to \(ReminderTiming.leadMinutes) min before you usually log"
        }
        return explanation.map { "\($0), \(rule.prefix(1).lowercased())\(rule.dropFirst())" } ?? rule
    }

    /// Rewords the reason with the on-device model once typing pauses. The
    /// app owns the time, so a reply that names one, or runs long, is dropped.
    /// A reason anchored to another habit is already specific and stays as is.
    private func phrase() async {
        let title = draft.trimmedTitle
        guard let suggestion, !suggestion.reason.contains(where: \.isNumber),
              (try? await Task.sleep(for: .milliseconds(600))) != nil else { return }
        let reply = await OnDeviceModel.phrase(
            "Habit: \(title). Reason for its reminder time: \(suggestion.reason).",
            instructions: "Reword the reason as one short, warm phrase in sentence case, under 40 characters. Do not mention a time or add facts that are not given. No em dashes, no final period."
        )
        guard !Task.isCancelled,
              let text = reply?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              text.count <= 45, !text.contains(where: \.isNumber)
        else { return }
        // The model does not always keep to sentence case.
        phrased = (title, text.prefix(1).uppercased() + text.dropFirst())
    }
}
