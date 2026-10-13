import SwiftData
import SwiftUI
import UIKit

/// The daily report: one card with everything on it. Pick a theme, switch off
/// anything you'd rather not share, add a note if you like, then text it or
/// share it. The card carries your name and the date, so a friend can forward
/// it and it still makes sense.
struct DailyReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitService.self) private var health

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @AppStorage(AppPreferences.reporterName) private var reporterName = ""
    @AppStorage(AppPreferences.reportTheme) private var themeRaw = ReportTheme.classic.rawValue
    @AppStorage(AppPreferences.reportHiddenHabits) private var hiddenRaw = ""
    @AppStorage(AppPreferences.reportShowStreaks) private var showStreaks = true
    @AppStorage(AppPreferences.reportShowNotes) private var showNotes = true
    @AppStorage(AppPreferences.reportShowWeek) private var showWeek = true
    @AppStorage(AppPreferences.reportShowCalories) private var showCalories = false
    @AppStorage(AppPreferences.reportShowActivity) private var showActivity = false

    let day: Date

    @State private var note = ""
    @State private var eatenText = ""
    @State private var metrics: DayHealthMetrics = .empty
    @State private var preview: UIImage?
    @State private var askedHealth = false
    /// Decided once on open, so the field does not vanish after one letter.
    @State private var askForName = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, note, eaten }

    init(day: Date) {
        self.day = day.startOfDay
    }

    // MARK: - Derived

    private var options: ReportOptions {
        ReportOptions(
            theme: ReportTheme(rawValue: themeRaw) ?? .classic,
            hiddenHabitIDs: ReportOptions.hiddenIDs(from: hiddenRaw),
            showStreaks: showStreaks,
            showNotes: showNotes,
            showWeek: showWeek,
            showCalories: showCalories,
            showActivity: showActivity,
            note: note
        )
    }

    /// Apple Health's numbers with a typed calorie total laid over them.
    private var effectiveMetrics: DayHealthMetrics {
        var merged = metrics
        let digits = eatenText.filter { "0123456789.".contains($0) }
        if let typed = Double(digits) {
            merged.eatenKcal = min(typed, 99_999)
        }
        return merged
    }

    private func makeReport(_ options: ReportOptions) -> DailyReport {
        DailyReportBuilder.build(
            habits: habits,
            day: day,
            options: options,
            name: reporterName,
            health: effectiveMetrics,
            liveValues: health.liveValues,
            liveWeeklyValues: health.liveWeeklyValues
        )
    }

    private var title: String {
        if day.isToday { return "Today's report" }
        if day.isYesterday { return "Yesterday's report" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    // MARK: - Body

    var body: some View {
        let options = options
        let report = makeReport(options)

        return NavigationStack {
            PageScrollView {
                VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                    cardPreview
                    themeRow
                    if askForName {
                        nameRow
                    }
                    habitsSection
                    extrasSection
                    noteSection
                }
                .padding(.horizontal, AppLayout.pageHorizontal)
                .padding(.bottom, AppLayout.pageBottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { AppBackground(style: .subtle) }
            .safeAreaBar(edge: .bottom) {
                actions(report: report, options: options)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground { AppBackground(style: .subtle) }
        .task {
            askForName = reporterName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        .task(id: options.needsHealth) { await loadHealth(needsHealth: options.needsHealth) }
        .task(id: PreviewKey(report: report, options: options)) {
            // A short pause lets typing settle before the card re-renders.
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            preview = ReportCardRenderer.render(report: report, options: options, scale: 2)
        }
    }

    // MARK: - Preview

    private var cardPreview: some View {
        Group {
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.55), radius: 24, y: 14)
                    .accessibilityLabel("Report card preview")
            } else {
                RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous)
                    .fill(AppColors.surfaceLift)
                    .aspectRatio(0.7, contentMode: .fit)
                    .overlay { ProgressView().tint(.white) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // MARK: - Theme

    private var themeRow: some View {
        GlassSection("Theme") {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(ReportTheme.allCases) { theme in
                        themeSwatch(theme)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, AppLayout.pageHorizontal, for: .scrollContent)
            .padding(.horizontal, -AppLayout.pageHorizontal)
        }
    }

    private func themeSwatch(_ theme: ReportTheme) -> some View {
        let isSelected = themeRaw == theme.rawValue
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            themeRaw = theme.rawValue
        } label: {
            VStack(spacing: 6) {
                Group {
                    if let look = theme.look {
                        CanvasLookView(look: look, mood: .session)
                    } else {
                        ReportPalette(theme: theme).paper
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous)
                        .strokeBorder(isSelected ? Color.white.opacity(0.95) : AppColors.cardStroke, lineWidth: isSelected ? 2 : 1)
                }

                Text(theme.displayName)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            }
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - What to share

    private var habitsSection: some View {
        GlassSection("Habits") {
            GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                ForEach(habits) { habit in
                    ListRowLabel(icon: habit.symbol, tint: habit.color, title: habit.title, trailing: .none) {
                        Toggle(habit.title, isOn: includes(habit))
                            .labelsHidden()
                            .tint(AppColors.primary)
                    }
                }
            }
        }
    }

    /// Asked once, the first time there is no name, so a forwarded card says
    /// whose day it was.
    private var nameRow: some View {
        GlassRowGroup(dividerInset: RowLayout.dividerInset) {
            SettingsRow("Your name", icon: "person", caption: "Printed on the card") {
                TextField("", text: $reporterName, prompt: Text("Add").foregroundStyle(.white.opacity(0.4)))
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .name)
                    .frame(maxWidth: 140)
            }
        }
    }

    private func includes(_ habit: Habit) -> Binding<Bool> {
        Binding(
            get: { !ReportOptions.hiddenIDs(from: hiddenRaw).contains(habit.id) },
            set: { isOn in
                var hidden = ReportOptions.hiddenIDs(from: hiddenRaw)
                if isOn { hidden.remove(habit.id) } else { hidden.insert(habit.id) }
                hiddenRaw = ReportOptions.raw(from: hidden)
                Haptics.selection()
            }
        )
    }

    private var extrasSection: some View {
        GlassSection("Also show") {
            GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                SettingsRow("Streaks", icon: "flame", isOn: $showStreaks)
                SettingsRow("Notes", icon: "text.quote", isOn: $showNotes)
                SettingsRow("Last 7 days", icon: "circle.grid.3x3", isOn: $showWeek)
                SettingsRow("Calories in vs out", icon: "fork.knife", isOn: $showCalories)
                if showCalories {
                    SettingsRow(
                        "Calories eaten",
                        icon: "number",
                        caption: metrics.eatenKcal == nil ? "Not in Apple Health. Type a total." : "From Apple Health"
                    ) {
                        TextField(
                            "",
                            text: $eatenText,
                            prompt: Text(metrics.eatenKcal.map { $0.safeRounded.formatted() } ?? "kcal")
                                .foregroundStyle(.white.opacity(0.4))
                        )
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .focused($focusedField, equals: .eaten)
                        .frame(maxWidth: 90)
                    }
                }
                SettingsRow("Steps, sleep and exercise", icon: "figure.walk", isOn: $showActivity)
            }
            .motion(AppMotion.settle, value: showCalories)
        }
    }

    private var noteSection: some View {
        GlassSection("Note") {
            TextField(
                "",
                text: $note,
                prompt: Text("Add a line to this card").foregroundStyle(.white.opacity(0.4)),
                axis: .vertical
            )
            .lineLimit(1...3)
            .focused($focusedField, equals: .note)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassCard()
        }
    }

    // MARK: - Actions

    /// The card goes alone: no message typed under it, so a friend gets one
    /// image they can forward as is.
    private func actions(report: DailyReport, options: ReportOptions) -> some View {
        HStack(spacing: 10) {
            if MessageComposer.canSend {
                GlassButton(title: "Text it", icon: "message.fill", style: .secondary, size: .large, fullWidth: true) {
                    guard let image = ReportCardRenderer.render(report: report, options: options) else { return }
                    Haptics.medium()
                    MessageComposer.shared.present(image: image)
                }
            }
            GlassButton(title: "Share", icon: "square.and.arrow.up", style: .primary, size: .large, fullWidth: true) {
                guard let image = ReportCardRenderer.render(report: report, options: options) else { return }
                Haptics.medium()
                SharePresenter.present(image: image)
            }
        }
        .padding(.horizontal, AppLayout.pageHorizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Health

    private func loadHealth(needsHealth: Bool) async {
        guard needsHealth else { return }
        if !askedHealth {
            askedHealth = true
            await health.requestReportAuthorization()
        }
        metrics = await health.dayMetrics(for: day)
    }
}

// MARK: - Keys

private nonisolated struct PreviewKey: Equatable {
    let report: DailyReport
    let options: ReportOptions
}
