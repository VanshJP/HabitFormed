import SwiftUI

/// Settings, pushed from Today's gear: the report's name and evening nudge,
/// the app's look, and feedback.
struct SettingsView: View {
    @Environment(NotificationService.self) private var notifications

    @AppStorage(AppPreferences.appCanvas) private var canvasRaw = AppCanvas.classic.rawValue
    @AppStorage(AppPreferences.glassAppearance) private var glassRaw = GlassAppearance.light.rawValue
    @AppStorage(AppPreferences.logSound) private var logSound = true
    @AppStorage(AppPreferences.reporterName) private var reporterName = ""
    @AppStorage(AppPreferences.reportReminderEnabled) private var reminderOn = false
    @AppStorage(AppPreferences.reportReminderHour) private var reminderHour = 21
    @AppStorage(AppPreferences.reportReminderMinute) private var reminderMinute = 0

    @State private var showArrange = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        PageScrollView {
            VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                reportSection
                lookSection
                habitsSection
                about
            }
            .padding(.horizontal, AppLayout.pageHorizontal)
            .padding(.vertical, AppLayout.pageBottom)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground() }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .restoresNavigationBar()
        .sheet(isPresented: $showArrange) { ArrangeHabitsSheet() }
        .onChange(of: reminderOn) { _, _ in syncReminder() }
        .onChange(of: reminderHour) { _, _ in syncReminder() }
        .onChange(of: reminderMinute) { _, _ in syncReminder() }
    }

    // MARK: - Report

    private var reportSection: some View {
        GlassSection("Daily report") {
            VStack(alignment: .leading, spacing: 8) {
                GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                    SettingsRow("Your name", icon: "person") {
                        TextField("", text: $reporterName, prompt: Text("Add").foregroundStyle(.white.opacity(0.4)))
                            .textContentType(.givenName)
                            .submitLabel(.done)
                            .multilineTextAlignment(.trailing)
                            .focused($nameFocused)
                            .frame(maxWidth: 160)
                    }
                    SettingsRow("Evening nudge", icon: "bell.badge", isOn: $reminderOn)
                    if reminderOn {
                        SettingsRow("Time", icon: "clock") {
                            DatePicker("Nudge time", selection: reminderTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                }
                .motion(AppMotion.settle, value: reminderOn)

                Text("Your name prints on every card, so a forwarded card still says whose day it was.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

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

    private func syncReminder() {
        Task {
            await notifications.syncReportReminder(enabled: reminderOn, hour: reminderHour, minute: reminderMinute)
        }
    }

    // MARK: - Look

    private var lookSection: some View {
        GlassSection("App look") {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(AppCanvas.allCases) { canvas in
                        canvasSwatch(canvas)
                    }
                }

                SectionPicker(
                    sections: GlassAppearance.allCases,
                    selection: Binding(
                        get: { GlassAppearance(rawValue: glassRaw) ?? .light },
                        set: { glassRaw = $0.rawValue }
                    ),
                    label: { "\($0.displayName) glass" },
                    style: .compact
                )
            }
        }
    }

    private func canvasSwatch(_ canvas: AppCanvas) -> some View {
        let isSelected = canvasRaw == canvas.rawValue
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            canvasRaw = canvas.rawValue
        } label: {
            VStack(spacing: 6) {
                CanvasLookView(look: canvas.look)
                    .frame(height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous)
                            .strokeBorder(isSelected ? Color.white.opacity(0.9) : AppColors.cardStroke, lineWidth: isSelected ? 2 : 1)
                    }
                Text(canvas.displayName)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            }
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(canvas.displayName)
        .accessibilityHint(canvas.look.summary)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Habits

    private var habitsSection: some View {
        GlassSection("Habits") {
            GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                Button {
                    Haptics.light()
                    showArrange = true
                } label: {
                    SettingsRow("Arrange habits", icon: "arrow.up.arrow.down", caption: "The order of the Today grid.", trailing: .chevron)
                }
                .buttonStyle(RowPressStyle())

                SettingsRow("Log sound", icon: "speaker.wave.2", caption: "A soft chime when you log a habit.", isOn: $logSound)
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
