import SwiftUI
import SwiftData

/// Settings, pushed from Today's gear: how Today looks and sounds, the
/// reports' name and reminders, and the app's look. One flat panel per
/// section, and few-way choices as chips in their row.
struct SettingsView: View {
    @Environment(NotificationService.self) private var notifications

    @AppStorage(AppPreferences.appCanvas) private var canvasRaw = AppCanvas.classic.rawValue
    @AppStorage(AppPreferences.glassAppearance) private var glassRaw = GlassAppearance.light.rawValue
    @AppStorage(AppPreferences.logSound) private var logSound = true
    @AppStorage(AppPreferences.todayLayout) private var layoutRaw = TodayLayout.tiles.rawValue
    @AppStorage(AppPreferences.reporterName) private var reporterName = ""
    @AppStorage(AppPreferences.reportReminderEnabled) private var reminderOn = false
    @AppStorage(AppPreferences.reportReminderHour) private var reminderHour = 21
    @AppStorage(AppPreferences.reportReminderMinute) private var reminderMinute = 0
    @AppStorage(AppPreferences.recapReminderEnabled) private var recapOn = false

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @State private var showArrange = false
    @State private var showReportCard = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        PageScrollView {
            VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                todaySection
                reportSection
                lookSection
                about
            }
            .padding(.top, 8)
            .pageContentInsets()
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground() }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .restoresNavigationBar()
        .sheet(isPresented: $showArrange) { ArrangeHabitsSheet() }
        .sheet(isPresented: $showReportCard) { DailyReportSheet(day: Date(), isPreset: true) }
        .onChange(of: reminderOn) { _, isOn in
            // Turning it on lands it just after the day usually wraps up.
            if isOn, let suggested = suggestedReminder {
                reminderHour = suggested.hour
                reminderMinute = suggested.minute
            }
            syncReminder()
        }
        .onChange(of: reminderHour) { _, _ in syncReminder() }
        .onChange(of: reminderMinute) { _, _ in syncReminder() }
        .onChange(of: recapOn) { _, isOn in
            Task { await notifications.syncRecapReminder(enabled: isOn) }
        }
    }

    // MARK: - Today

    private var todaySection: some View {
        GlassSection("Today") {
            Panel {
                LayoutPicker(selection: Binding(
                    get: { TodayLayout(rawValue: layoutRaw) ?? .tiles },
                    set: { layoutRaw = $0.rawValue }
                ))
                Button {
                    Haptics.light()
                    showArrange = true
                } label: {
                    SettingsRow("Arrange habits", icon: "arrow.up.arrow.down", trailing: .chevron)
                }
                .buttonStyle(RowPressStyle())
                SettingsRow("Log sound", icon: "speaker.wave.2", isOn: $logSound)
                // Voice commands are invisible until someone says the words.
                SettingsRow("Siri", icon: "mic", caption: siriPhrase)
            }
        }
    }

    private var siriPhrase: String {
        let habit = habits.first(where: { $0.trackKind != .health })?.title ?? "Read"
        return "Say “Log \(habit) in Habit Formed”"
    }

    // MARK: - Reports

    private var reportSection: some View {
        GlassSection("Reports") {
            Panel {
                SettingsRow("Name on reports", icon: "person") {
                    TextField("", text: $reporterName, prompt: Text("Add").foregroundStyle(.white.opacity(0.4)))
                        .textContentType(.givenName)
                        .submitLabel(.done)
                        .multilineTextAlignment(.trailing)
                        .focused($nameFocused)
                        .frame(maxWidth: 140)
                }
                Button {
                    Haptics.light()
                    showReportCard = true
                } label: {
                    SettingsRow("Report style", icon: "rectangle.portrait", trailing: .chevron)
                }
                .buttonStyle(RowPressStyle())
                SettingsRow("Daily reminder", icon: "bell", caption: reminderCaption, accessoryIsLabelled: true) {
                    if reminderOn {
                        DatePicker("Reminder time", selection: reminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    SettingsToggle(title: "Daily reminder", isOn: $reminderOn)
                }
                SettingsRow("Weekly recap", icon: "calendar", accessoryIsLabelled: true) {
                    if recapOn {
                        Text("\(Calendar.current.shortWeekdaySymbols[0]) \(Self.recapTime.label)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    SettingsToggle(title: "Weekly recap on Sundays at \(Self.recapTime.label)", isOn: $recapOn)
                }
            }
            .motion(AppMotion.snap, value: reminderOn)
            .motion(AppMotion.snap, value: recapOn)
        }
    }

    /// When the Sunday nudge rings (`NotificationService.syncRecapReminder`),
    /// in the person's own clock format.
    private static let recapTime = ReminderTime(hour: 19, minute: 0)

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = parts.hour ?? 21
                reminderMinute = parts.minute ?? 0
            }
        )
    }

    /// When the day's last log usually lands, from logs made on their own day.
    /// Health logs are written by sync, so they say nothing about the day.
    private var usualDayEnd: Int? {
        var last: [Date: Date] = [:]
        for habit in habits where habit.trackKind != .health {
            for log in habit.completions ?? [] where log.loggedAt.isSameDay(as: log.date) {
                last[log.date] = max(last[log.date] ?? log.loggedAt, log.loggedAt)
            }
        }
        return ReminderTiming.typicalMinute(of: last.values.sorted(by: >))
    }

    private var suggestedReminder: ReminderTime? {
        usualDayEnd.map { ReminderTiming.reminder(afterTypical: $0) }
    }

    /// Why the suggested time, while it is the time (or would be, once on).
    private var reminderCaption: String? {
        guard let suggested = suggestedReminder else { return nil }
        let why = "\(ReminderTiming.leadMinutes) min after your usual last log"
        guard reminderOn else { return "\(suggested.label), \(why)" }
        return suggested == ReminderTime(hour: reminderHour, minute: reminderMinute) ? why : nil
    }

    private func syncReminder() {
        Task {
            await notifications.syncReportReminder(enabled: reminderOn, hour: reminderHour, minute: reminderMinute)
        }
    }

    // MARK: - Look

    private var lookSection: some View {
        GlassSection("Look") {
            VStack(alignment: .leading, spacing: 12) {
                SwatchRail(
                    items: AppCanvas.allCases,
                    selection: Binding(
                        get: { AppCanvas(rawValue: canvasRaw) ?? .classic },
                        set: { canvasRaw = $0.rawValue }
                    ),
                    name: \.displayName
                ) { canvas in
                    CanvasLookView(look: canvas.look)
                }
                Panel {
                    SettingsRow("Glass", icon: "circle.lefthalf.filled") {
                        ForEach(GlassAppearance.allCases) { glass in
                            ChoiceChip(title: glass.displayName, isSelected: glassRaw == glass.rawValue) {
                                glassRaw = glass.rawValue
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - About

    private var about: some View {
        Text("Habit Formed \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}
