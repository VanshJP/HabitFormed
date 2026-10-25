import SwiftData
import SwiftUI
import UIKit

/// The report sheet: one card for the day, the week or the year so far,
/// picked at the top, in the look set ahead of time, so sending is the card,
/// a note if you like, and Text it or Share, always in reach at the foot.
/// Edit (or a tap on the card) opens the studio, where the card is edited
/// on itself; whatever is picked there is the look next time too. Settings
/// opens the studio alone (`isPreset`), with nothing to send. Every card
/// carries your name, so a friend can forward it and it still makes sense.
struct ReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitService.self) private var health
    @Environment(\.appCanvas) private var canvas
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @AppStorage(AppPreferences.reporterName) private var reporterName = ""
    @AppStorage(AppPreferences.reportTheme) private var themeRaw = ReportTheme.app.rawValue
    @AppStorage(AppPreferences.reportLayout) private var layoutRaw = ReportLayout.list.rawValue
    @AppStorage(AppPreferences.reportYearLayout) private var yearLayoutRaw = YearLayout.pixels.rawValue
    @AppStorage(AppPreferences.reportRing) private var ringRaw = ReportRing.big.rawValue
    @AppStorage(AppPreferences.reportAccent) private var accentHex = ""
    @AppStorage(AppPreferences.reportFont) private var fontRaw = ReportFont.standard.rawValue
    @AppStorage(AppPreferences.reportHiddenHabits) private var hiddenRaw = ""
    @AppStorage(AppPreferences.reportShowStreaks) private var showStreaks = true
    @AppStorage(AppPreferences.reportShowNotes) private var showNotes = true
    @AppStorage(AppPreferences.reportShowWeek) private var showWeek = true
    @AppStorage(AppPreferences.reportMetrics) private var metricsRaw = ReportOptions.legacyMetricsRaw

    /// The card's day: the day itself, the last of the week, or how far
    /// into its year the year card runs.
    let day: Date
    /// Opened from Settings to set the look: always the studio, nothing to send.
    let isPreset: Bool

    @State private var scope: ReportScope
    @State private var isEditing = false
    @State private var tool: ReportTool = .layout
    @State private var note = ""
    @State private var typed = ReportTypedAmounts()
    @State private var metrics: DayHealthMetrics = .empty
    @State private var askedHealth = false

    init(day: Date, scope: ReportScope = .day, isPreset: Bool = false) {
        self.day = day.startOfDay
        self.isPreset = isPreset
        _scope = State(initialValue: scope)
    }

    // MARK: - Derived

    private var options: ReportOptions {
        ReportOptions(
            theme: ReportTheme(rawValue: themeRaw) ?? .app,
            appLook: canvas.look,
            layout: ReportLayout(rawValue: layoutRaw) ?? .list,
            yearLayout: YearLayout(rawValue: yearLayoutRaw) ?? .pixels,
            ring: ReportRing(rawValue: ringRaw) ?? .big,
            accentHex: accentHex,
            font: ReportFont(rawValue: fontRaw) ?? .standard,
            hiddenHabitIDs: ReportOptions.hiddenIDs(from: hiddenRaw),
            showStreaks: showStreaks,
            showNotes: showNotes,
            showWeek: showWeek,
            metrics: ReportOptions.metrics(from: metricsRaw),
            note: note
        )
    }

    /// Health is the day card's alone.
    private var needsHealth: Bool { scope == .day && !ReportOptions.metrics(from: metricsRaw).isEmpty }

    private func build(_ options: ReportOptions) -> ReportBuilt {
        switch scope {
        case .day:
            return .day(DailyReportBuilder.build(
                habits: habits,
                day: day,
                options: options,
                name: reporterName,
                health: typed.applied(to: metrics),
                liveValues: health.liveValues,
                liveWeeklyValues: health.liveWeeklyValues
            ))
        case .week:
            return .week(WeeklyRecapBuilder.build(habits: habits, ending: day, name: reporterName, hidden: options.hiddenHabitIDs))
        case .year:
            return .year(YearReportBuilder.build(habits: habits, ending: day, name: reporterName, hidden: options.hiddenHabitIDs))
        }
    }

    private var title: String {
        if isPreset { return "Report style" }
        switch scope {
        case .day:
            if day.isToday { return "Today" }
            if day.isYesterday { return "Yesterday" }
            return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        case .week:
            if day.isToday { return "Last 7 days" }
            return "7 days to \(day.formatted(.dateTime.month(.abbreviated).day()))"
        case .year:
            let year = day.formatted(.dateTime.year())
            return Calendar.current.isDate(day, equalTo: Date(), toGranularity: .year) ? "\(year) so far" : year
        }
    }

    // MARK: - Body

    var body: some View {
        let options = options
        let built = build(options)

        return NavigationStack {
            Group {
                if isPreset || isEditing {
                    studio(built, options)
                } else {
                    sendPage(built, options)
                }
            }
            .safeAreaBar(edge: .top) {
                ReportScopePicker(scope: $scope)
                    .padding(.horizontal, AppLayout.pageHorizontal)
                    .padding(.bottom, 6)
            }
            .safeAreaBar(edge: .bottom) {
                // Always in reach while sending, so a tall card never pushes
                // it out of sight; the studio needs the room for its tools.
                if !isPreset && !isEditing {
                    ReportSendBar { built.image(options: options) }
                        .pinnedBar()
                        .readableColumn()
                }
            }
            .background { AppBackground(style: .subtle) }
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
        .task(id: needsHealth) { await loadHealth() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await loadHealth() } }
        }
    }

    // MARK: - Send

    /// The card as it will be sent, then what can be typed onto it. A tap on
    /// the card opens the studio.
    private func sendPage(_ built: ReportBuilt, _ options: ReportOptions) -> some View {
        PageScrollView {
            VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                ReportPreview { ReportBuiltPoster(built: built, options: options) }
                    // A new look or switch eases in; the note is left out so
                    // typing does not animate every letter.
                    .motion(AppMotion.settle, value: options.style)
                    .motion(AppMotion.settle, value: scope)
                    .contentShape(.rect)
                    .onTapGesture { openStudio() }
                    .accessibilityAction(named: "Edit the card") { openStudio() }
                ReportSheetFields(
                    scope: scope,
                    picked: options.metrics,
                    health: metrics,
                    note: $note,
                    typed: $typed
                )
            }
            .padding(.horizontal, AppLayout.pageHorizontal)
            .padding(.bottom, AppLayout.pageBottom)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func openStudio() {
        Haptics.light()
        withMotion(AppMotion.settle) { isEditing = true }
    }

    // MARK: - Studio

    private func studio(_ built: ReportBuilt, _ options: ReportOptions) -> some View {
        let tools = ReportTool.tools(for: scope)
        let current = tools.contains(tool) ? tool : .content
        return ReportStudio(tools: tools, tool: Binding(get: { current }, set: { tool = $0 })) {
            ReportBuiltPoster(built: built, options: options)
                .environment(\.reportRegionTap, { region in
                    Haptics.selection()
                    withMotion(AppMotion.settle) { tool = ReportTool.tool(for: region, in: scope) }
                })
                .environment(\.reportActiveRegion, current.region)
                .motion(AppMotion.settle, value: options.style)
        } content: {
            switch current {
            case .layout:
                switch built {
                case .day(let report): ReportDayLayoutTool(report: report, options: options)
                case .year(let year): ReportYearLayoutTool(year: year, options: options)
                case .week: EmptyView()
                }
            case .content:
                ReportContentTool(scope: scope, layout: options.layout, note: isPreset ? nil : $note)
            case .style:
                ReportStyleTool(scope: scope, layout: options.layout)
            }
        }
    }

    // MARK: - Health

    /// Reads Health afresh, habits included, so the card never prints the
    /// last sync's totals beside a newer reading.
    private func loadHealth() async {
        await health.syncHealthKitHabits(in: modelContext)
        guard needsHealth else { return }
        if !askedHealth {
            askedHealth = true
            await health.requestReportAuthorization()
        }
        metrics = await health.dayMetrics(for: day)
    }
}

// MARK: - Built card

/// A card's contents, built for the scope the sheet shows.
enum ReportBuilt {
    case day(DailyReport)
    case week(WeeklyRecap)
    case year(YearReport)

    /// The image that is sent, drawn at the moment of sending.
    func image(options: ReportOptions) -> UIImage? {
        switch self {
        case .day(let report): return ReportCardRenderer.render(report: report, options: options)
        case .week(let recap): return ReportCardRenderer.render(recap: recap, options: options)
        case .year(let year): return ReportCardRenderer.render(year: year, options: options)
        }
    }
}

/// The poster that is sent, for whichever card was built.
struct ReportBuiltPoster: View {
    let built: ReportBuilt
    let options: ReportOptions

    var body: some View {
        switch built {
        case .day(let report):
            ReportPosterView(backdrop: ReportCardView.backdrop(for: options)) {
                ReportCardView(report: report, options: options)
            }
        case .week(let recap):
            ReportPosterView(backdrop: ReportBackdrop(options: options)) {
                WeeklyRecapCardView(recap: recap, options: options)
            }
        case .year(let year):
            ReportPosterView(backdrop: ReportBackdrop(options: options)) {
                YearReportCardView(report: year, options: options)
            }
        }
    }
}
