import SwiftData
import SwiftUI
import UIKit

/// The daily report: one card with everything on it, in the look set ahead
/// of time, so sending is the card, a note if you like, and Text it or Share.
/// Edit opens the theme and what is on the card; whatever is picked there is
/// the look next time too. Settings opens the same sheet as a preset
/// (`isPreset`), with nothing to send. The card carries your name and the
/// date, so a friend can forward it and it still makes sense.
struct DailyReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitService.self) private var health

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @AppStorage(AppPreferences.reporterName) private var reporterName = ""
    @AppStorage(AppPreferences.reportTheme) private var themeRaw = ReportTheme.app.rawValue
    @Environment(\.appCanvas) private var canvas
    @AppStorage(AppPreferences.reportLayout) private var layoutRaw = ReportLayout.list.rawValue
    @AppStorage(AppPreferences.reportAccent) private var accentHex = ""
    @AppStorage(AppPreferences.reportFont) private var fontRaw = ReportFont.standard.rawValue
    @AppStorage(AppPreferences.reportHiddenHabits) private var hiddenRaw = ""
    @AppStorage(AppPreferences.reportShowStreaks) private var showStreaks = true
    @AppStorage(AppPreferences.reportShowNotes) private var showNotes = true
    @AppStorage(AppPreferences.reportShowWeek) private var showWeek = true
    @AppStorage(AppPreferences.reportMetrics) private var metricsRaw = ReportOptions.legacyMetricsRaw

    let day: Date
    /// Opened from Settings to set the look: always editing, nothing to send.
    let isPreset: Bool

    @State private var isEditing = false
    @State private var note = ""
    @State private var eatenText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var metrics: DayHealthMetrics = .empty
    @State private var askedHealth = false
    /// Decided once on open, so the field does not vanish after one letter.
    @State private var askForName = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, note, eaten }

    init(day: Date, isPreset: Bool = false) {
        self.day = day.startOfDay
        self.isPreset = isPreset
    }

    // MARK: - Derived

    private var options: ReportOptions {
        ReportOptions(
            theme: ReportTheme(rawValue: themeRaw) ?? .app,
            appLook: canvas.look,
            layout: ReportLayout(rawValue: layoutRaw) ?? .list,
            accentHex: accentHex,
            font: ReportFont(rawValue: fontRaw) ?? .standard,
            hiddenHabitIDs: ReportOptions.hiddenIDs(from: hiddenRaw),
            showStreaks: showStreaks,
            showNotes: showNotes,
            showWeek: showWeek,
            metrics: picked,
            note: note
        )
    }

    private var picked: Set<ReportMetric> { ReportOptions.metrics(from: metricsRaw) }

    /// Apple Health's numbers with whatever was typed laid over them.
    private var effectiveMetrics: DayHealthMetrics {
        var merged = metrics
        if let typed = Self.typedAmount(eatenText, cap: 99_999) { merged.eatenKcal = typed }
        if let typed = Self.typedAmount(proteinText, cap: 9_999) { merged.protein = typed }
        if let typed = Self.typedAmount(carbsText, cap: 9_999) { merged.carbs = typed }
        if let typed = Self.typedAmount(fatText, cap: 9_999) { merged.fat = typed }
        return merged
    }

    /// A typed amount, digits only, capped so the card's columns hold it.
    private static func typedAmount(_ text: String, cap: Double) -> Double? {
        let digits = text.filter { "0123456789.".contains($0) }
        return Double(digits).map { min($0, cap) }
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
        if isPreset { return "Report style" }
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
                    ReportPreview(width: ReportCardView.width) {
                        ReportCardView(report: report, options: options)
                    }
                    // A new look or switch eases in; the note is left out so
                    // typing does not animate every letter.
                    .motion(AppMotion.settle, value: { var style = options; style.note = ""; return style }())
                    if !isPreset {
                        fields
                        // Right under the note while only sending, so a short
                        // card is not left floating far above the button.
                        if !isEditing {
                            ReportSendBar { ReportCardRenderer.render(report: report, options: options) }
                        }
                    }
                    if isPreset || isEditing {
                        ReportStyleEditor()
                    }
                }
                .motion(AppMotion.settle, value: isEditing)
                .padding(.horizontal, AppLayout.pageHorizontal)
                .padding(.bottom, AppLayout.pageBottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { AppBackground(style: .subtle) }
            .safeAreaBar(edge: .bottom) {
                // Editing makes the page long, so the button stays in reach.
                if !isPreset && isEditing {
                    ReportSendBar { ReportCardRenderer.render(report: report, options: options) }
                        .pinnedBar()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
                if !isPreset {
                    ToolbarItem(placement: .topBarTrailing) {
                        ReportEditButton(isEditing: $isEditing)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground { AppBackground(style: .subtle) }
        .task {
            askForName = reporterName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        .task(id: options.needsHealth) { await loadHealth(needsHealth: options.needsHealth) }
    }

    /// What you type onto the card, in one panel: your name (asked once,
    /// the first time there is none), calories eaten and the macros while
    /// they are on, and this card's note.
    private var fields: some View {
        Panel {
            if askForName {
                SettingsRow("Name on reports", icon: "person") {
                    TextField("", text: $reporterName, prompt: Text("Add").foregroundStyle(.white.opacity(0.4)))
                        .textContentType(.givenName)
                        .submitLabel(.done)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .name)
                        .frame(maxWidth: 140)
                }
            }
            if picked.contains(.calories) {
                SettingsRow("Calories eaten", icon: ReportMetric.calories.icon) {
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
            if picked.contains(.macros) {
                MacroFieldsRow(protein: $proteinText, carbs: $carbsText, fat: $fatText, health: metrics)
            }
            HStack(spacing: RowLayout.spacing) {
                RowGlyph(icon: "square.and.pencil", tint: .secondary)
                TextField(
                    "",
                    text: $note,
                    prompt: Text("Add a note to this report").foregroundStyle(.white.opacity(0.4)),
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
        .motion(AppMotion.settle, value: metricsRaw)
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
