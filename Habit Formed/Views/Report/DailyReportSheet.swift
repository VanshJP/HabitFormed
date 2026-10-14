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
                    ReportPreview(image: preview)
                    ReportThemeRow(themeRaw: $themeRaw)
                    contentsSection
                    fields
                }
                .padding(.horizontal, AppLayout.pageHorizontal)
                .padding(.bottom, AppLayout.pageBottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { AppBackground(style: .subtle) }
            .safeAreaBar(edge: .bottom) {
                ReportSendBar { ReportCardRenderer.render(report: report, options: options) }
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

    // MARK: - What to share

    /// Everything the card can show, as chips: the habits first, then the
    /// extras. The preview above shows each one come and go.
    private var contentsSection: some View {
        GlassSection("On the card") {
            VStack(alignment: .leading, spacing: 4) {
                FlowLayout(spacing: 8) {
                    ForEach(habits) { habit in
                        ToggleChip(title: habit.title, icon: habit.symbol, tint: habit.color, isOn: includes(habit))
                    }
                }
                FlowLayout(spacing: 8) {
                    ToggleChip(title: "Streaks", icon: "flame", isOn: $showStreaks)
                    ToggleChip(title: "Habit notes", icon: "text.quote", isOn: $showNotes)
                    ToggleChip(title: "Last 7 days", icon: "circle.grid.3x3", isOn: $showWeek)
                    ToggleChip(title: "Calories", icon: "fork.knife", isOn: $showCalories)
                    ToggleChip(title: "Activity", icon: "figure.walk", isOn: $showActivity)
                }
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
            }
        )
    }

    /// What you type onto the card, in one panel: your name (asked once,
    /// the first time there is none), calories eaten while they are on, and
    /// this card's note.
    private var fields: some View {
        Panel {
            if askForName {
                SettingsRow("Name on cards", icon: "person") {
                    TextField("", text: $reporterName, prompt: Text("Add").foregroundStyle(.white.opacity(0.4)))
                        .textContentType(.givenName)
                        .submitLabel(.done)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .name)
                        .frame(maxWidth: 140)
                }
            }
            if showCalories {
                SettingsRow("Calories eaten", icon: "fork.knife") {
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
            HStack(spacing: RowLayout.spacing) {
                RowGlyph(icon: "square.and.pencil", tint: .secondary)
                TextField(
                    "",
                    text: $note,
                    prompt: Text("Add a note to this card").foregroundStyle(.white.opacity(0.4)),
                    axis: .vertical
                )
                .font(.subheadline)
                .lineLimit(1...3)
                .focused($focusedField, equals: .note)
            }
            .padding(.horizontal, RowLayout.horizontalPadding)
            .padding(.vertical, RowLayout.verticalPadding)
            .frame(minHeight: AppLayout.minHitTarget)
        }
        .motion(AppMotion.settle, value: showCalories)
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
