import AppIntents
import SwiftUI
import SwiftData

/// Today, the app's root page: a header with the doors to History and
/// Settings, a week strip to jump between recent days
/// (its rings are the day's progress), the habits as tiles or rows, each
/// filled with its color once done. The report is a door in the header.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HealthKitService.self) private var health
    @Environment(NotificationService.self) private var notifications
    @Environment(TimerCenter.self) private var timerCenter
    @Environment(DayTracker.self) private var dayTracker
    @Environment(\.appCanvas) private var canvas

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    var onAdd: () -> Void = {}
    var onShareReport: (Date) -> Void = { _ in }
    var onShareWeek: () -> Void = {}

    @State private var sheet: HabitSheet?
    @State private var openHabit: Habit?
    @State private var pendingDelete: Habit?
    @State private var pendingStop: Habit?
    @State private var selectedDate: Date = .now
    /// The last day the week strip shows; nil keeps it on today. Only the
    /// calendar and "Today" move it, so tapping a strip day never slides the
    /// strip under the finger.
    @State private var stripAnchor: Date?
    @State private var showDatePicker = false
    @State private var showArrange = false
    @State private var undo: UndoLog?
    @State private var celebration = 0

    @AppStorage(AppPreferences.todayLayout) private var layoutRaw = TodayLayout.tiles.rawValue

    /// The Health types today's habits read, so Health is only ever asked
    /// for those.
    private var healthSources: Set<HealthKitSource> {
        Set(habits.map(\.source).filter { $0 != .none })
    }

    private var isViewingToday: Bool {
        // Against `dayTracker.today` so a midnight rollover flips this.
        selectedDate.isSameDay(as: dayTracker.today)
    }

    var body: some View {
        // Re-render when the calendar day rolls over so today's state
        // (header counter, tile state) reflects reality at midnight.
        let _ = dayTracker.today
        // The toast sits over the whole page, not on the scroll view: on
        // the scroll view, taps on it fell through to the header under it.
        return lifecycle(presentations(page))
            .overlay(alignment: .top) { undoToast }
    }

    // MARK: - Page

    private var page: some View {
        let tracks = habits.map(\.track)
        let week = DayLedger.summaries(endingOn: stripEnd, count: 7, tracks: tracks)
        let todayIsPerfect = DayLedger.summary(on: dayTracker.today, tracks: tracks).isPerfect
        let shownDay = selectedDate.startOfDay
        let doneIDs = Set(tracks.filter { $0.logDays.contains(shownDay) }.map(\.id))

        return PageScrollView {
            VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                // The strip belongs to the header, so it sits close under it.
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                    if !habits.isEmpty {
                        WeekStrip(summaries: week, selectedDate: $selectedDate)
                    }
                }

                if habits.isEmpty {
                    EmptyStateCard(
                        icon: "circle.hexagongrid",
                        title: "No habits yet",
                        message: "Pick an idea or name your own. Slide a tile to log it each day.",
                        buttonTitle: "Add a habit",
                        buttonAction: onAdd
                    )
                } else {
                    // No title or count over the grid: the strip's ring is the
                    // day's progress and its glass the day shown.
                    TodayHabitList(
                        habits: habits,
                        layout: TodayLayout(rawValue: layoutRaw) ?? .tiles,
                        selectedDate: selectedDate,
                        isPastDay: !isViewingToday,
                        doneIDs: doneIDs,
                        actions: actions(for:)
                    )

                    // A finished day's report is the one thing left to do, so
                    // it becomes the page's solid button instead of a link.
                    if isViewingToday && todayIsPerfect {
                        GlassButton(
                            title: "Share today's report",
                            icon: "square.and.arrow.up",
                            style: .primary,
                            size: .large,
                            fullWidth: true
                        ) {
                            onShareReport(Date())
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if !isViewingToday {
                        Button {
                            Haptics.selection()
                            backToToday()
                        } label: {
                            HeaderLinkLabel("Today", icon: "arrow.uturn.forward")
                        }
                        .buttonStyle(.textLink)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .pageContentInsets()
        }
        .refreshable { await refreshHealth() }
        .overlay {
            if celebration > 0 {
                ConfettiView(origin: UnitPoint(x: 0.5, y: 0.2))
                    .id(celebration)
                    .ignoresSafeArea()
            }
        }
        .motion(AppMotion.settle, value: undo?.id)
        .motion(AppMotion.settle, value: todayIsPerfect)
        .onChange(of: todayIsPerfect) { wasPerfect, isPerfect in
            // Celebrate the log that finishes the day, never a page load.
            guard isPerfect, !wasPerfect, isViewingToday else { return }
            Haptics.celebrate()
            SoundEffects.perfectDay()
            celebration += 1
            // The toast that followed the finishing log says so; the report
            // button under the grid takes it from there.
            if var last = undo, last.wasLogged, last.day.isToday {
                last.completesDay = true
                undo = last
            }
        }
    }

    private func actions(for habit: Habit) -> HabitActions {
        HabitActions(
            open: { openHabit = habit },
            log: { logToday(habit) },
            undoToday: { undoToday(habit) },
            togglePastDay: { togglePastDay(habit) },
            edit: { sheet = .edit(habit) },
            arrange: { showArrange = true },
            requestDelete: { pendingDelete = habit },
            startTimer: { sheet = .timer(habit) },
            requestStopTimer: { pendingStop = habit }
        )
    }

    @ViewBuilder
    private var undoToast: some View {
        if let undo {
            UndoToast(
                message: undo.message,
                icon: undo.icon,
                tint: undo.tint,
                // "Perfect day" stays a little longer.
                lifetime: .seconds(undo.completesDay ? 6 : 4),
                onUndo: { revert(undo) },
                onDismiss: { if self.undo?.id == undo.id { self.undo = nil } }
            )
                .padding(.horizontal, AppLayout.pageHorizontal)
                .padding(.top, 4)
                .readableColumn()
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Presentations

    private func presentations<V: View>(_ content: V) -> some View {
        content
            .navigationDestination(item: $openHabit) { habit in
                HabitDetailView(habit: habit)
            }
            .sheet(item: $sheet) { item in
                switch item {
                case .edit(let habit): AddHabitView(habit: habit)
                case .timer(let habit): TimerView(habit: habit)
                }
            }
            // Full height: iOS 26 floats a shorter sheet clear of the
            // screen's edges, and this one should rise from the bottom.
            .sheet(isPresented: $showDatePicker, onDismiss: anchorStrip) {
                DateBrowserSheet(selectedDate: $selectedDate)
            }
            .sheet(isPresented: $showArrange) {
                ArrangeHabitsSheet()
            }
            .alert(
                "Delete this habit?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                presenting: pendingDelete
            ) { habit in
                Button("Delete", role: .destructive) { delete(habit) }
                Button("Cancel", role: .cancel) {}
            } message: { habit in
                Text("This permanently deletes \(habit.title) and its history.")
            }
            .confirmationDialog(
                "Stop the timer for \(pendingStop?.title ?? "this habit")?",
                isPresented: Binding(
                    get: { pendingStop != nil },
                    set: { if !$0 { pendingStop = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Stop", role: .destructive) {
                    Haptics.warning()
                    timerCenter.stop()
                }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("This session won't be logged.")
            }
    }

    // MARK: - Lifecycle

    private func lifecycle<V: View>(_ content: V) -> some View {
        content
            .task {
                WidgetSync.refresh(habits: habits, in: modelContext)
                // Permission is requested lazily when a reminder is turned on.
                await notifications.syncReminders(for: habits)
            }
            .task(id: healthSources) {
                // Health is asked for only what habits read, never on a bare
                // first launch. The add sheet asks first when one is saved.
                guard !healthSources.isEmpty else { return }
                try? await health.requestAuthorization(for: healthSources)
                await health.syncHealthKitHabits(in: modelContext)
                // HealthKit change notifications keep health tiles near
                // real-time; the slow poll only catches what they miss.
                health.startObservingHealthKitHabits(in: modelContext)
                while (try? await Task.sleep(for: .seconds(300))) != nil {
                    await health.syncHealthKitHabits(in: modelContext)
                }
            }
            .task(id: habits.map(\.title)) {
                // Siri learns habit names only from this call.
                HabitShortcuts.updateAppShortcutParameters()
            }
            .onChange(of: reminderSignature) { _, _ in
                Task { await notifications.syncReminders(for: habits) }
            }
            .onChange(of: WidgetSync.signature(habits: habits, today: dayTracker.today)) { _, _ in
                WidgetSync.update(habits: habits)
            }
            .onReceive(NotificationCenter.default.publisher(for: .habitLoggedFromWidget)) { _ in
                WidgetSync.refresh(habits: habits, in: modelContext)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    dayTracker.refresh()
                    WidgetSync.refresh(habits: habits, in: modelContext)
                    Task {
                        await health.syncHealthKitHabits(in: modelContext)
                        health.startObservingHealthKitHabits(in: modelContext)
                        // Picks up permission grants made in iOS Settings and
                        // re-anchors interval reminder chains after time away.
                        await notifications.syncReminders(for: habits)
                    }
                }
            }
    }

    // MARK: - Header

    /// The month is the date control: tap it for the calendar. The week strip
    /// under it does the day-to-day browsing, so there is no separate title.
    private var topBar: some View {
        HStack(alignment: .center) {
            Button {
                Haptics.light()
                showDatePicker = true
            } label: {
                // As big as fits beside the four doors: `.largeTitle`
                // squeezes "September" past the scale floor.
                HStack(spacing: 6) {
                    Text(monthTitle)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    // The capsule's icon weight, in the accent the calendar
                    // it opens wears.
                    Image(systemName: "chevron.down")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(canvas.look.accent)
                }
                .frame(minHeight: AppLayout.minHitTarget)
                .contentShape(.rect)
            }
            .buttonStyle(GlassPressStyle())
            .accessibilityLabel("\(monthTitle), pick a date")

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(GlassPressStyle())
                .accessibilityLabel("Add habit")

                // The day shown, so a browsed day shares its own report.
                Button { onShareReport(selectedDate) } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(GlassPressStyle())
                .accessibilityLabel("Share report")

                NavigationLink {
                    HistoryView(onShareReport: onShareReport, onShareWeek: onShareWeek)
                } label: {
                    Image(systemName: "clock")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(GlassPressStyle())
                .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
                .accessibilityLabel("History")

                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(GlassPressStyle())
                .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 2)
            .headerGlass()
            // Sized first, so the month shrinks instead of the doors.
            .layoutPriority(1)
        }
        .padding(.top, 4)
    }

    /// "October", or "October 2025" outside the current year.
    private var monthTitle: String {
        let sameYear = Calendar.current.isDate(selectedDate, equalTo: dayTracker.today, toGranularity: .year)
        return sameYear
            ? selectedDate.formatted(.dateTime.month(.wide))
            : selectedDate.formatted(.dateTime.month(.wide).year())
    }

    private var stripEnd: Date {
        stripAnchor ?? dayTracker.today
    }

    /// After the calendar closes: keep the strip on this week when the picked
    /// day is in it, otherwise move it back so the picked day sits inside.
    private func anchorStrip() {
        let today = dayTracker.today
        let selected = selectedDate.startOfDay
        stripAnchor = selected < today.adding(days: -6) ? min(today, selected.adding(days: 3)) : nil
    }

    /// Lands at once, like a strip tap; the strip's glass glides on its own.
    private func backToToday() {
        selectedDate = .now
        stripAnchor = nil
    }

    // MARK: - Reminder signature

    /// Order-insensitive fingerprint of every habit field that reminder
    /// scheduling depends on. Includes completion counts so logging or
    /// removing a log re-anchors interval chains, weekly bodies and learned
    /// reminder times.
    private var reminderSignature: String {
        habits
            .map { habit in
                [
                    habit.id.uuidString,
                    String(habit.reminderEnabled),
                    String(habit.reminderLearnsTime),
                    "\(habit.reminderHour):\(habit.reminderMinute)",
                    habit.reminderWeekdaysRaw,
                    habit.frequencyRaw,
                    habit.sourceRaw,
                    String(habit.weeklyTarget),
                    String(habit.intervalDays),
                    habit.title,
                    String(habit.completions?.count ?? 0),
                    String(habit.lastCompletionDate?.timeIntervalSince1970 ?? 0),
                ].joined(separator: "|")
            }
            .sorted()
            .joined(separator: ";")
    }

    // MARK: - Actions

    private func logToday(_ habit: Habit) {
        guard isViewingToday, habit.log(on: Date(), in: modelContext) != nil else { return }
        // Every log from Today lands here, so the chime can climb with the day.
        let today = DayLedger.summary(on: dayTracker.today, tracks: habits.map(\.track))
        SoundEffects.logChime(progress: today.fraction)
        undo = UndoLog(habit: habit, day: Date(), wasLogged: true)
    }

    private func undoToday(_ habit: Habit) {
        Haptics.undo()
        // The toast for this log would offer to take back what is gone.
        if let last = undo, last.habitID == habit.id, last.wasLogged, last.day.isToday { undo = nil }
        withMotion(AppMotion.snap) { habit.removeLog(on: Date(), in: modelContext) }
    }

    /// A past day logs with a slide and loses its log only from the menu,
    /// so neither happens by accident; the toast offers the way back. The
    /// slide or the menu plays the log's haptic.
    private func togglePastDay(_ habit: Habit) {
        let day = selectedDate
        if habit.isCompleted(on: day) {
            Haptics.undo()
            habit.removeLog(on: day, in: modelContext)
            undo = UndoLog(habit: habit, day: day, wasLogged: false)
        } else {
            SoundEffects.logChime()
            habit.log(on: day, in: modelContext)
            undo = UndoLog(habit: habit, day: day, wasLogged: true)
        }
    }

    private func revert(_ change: UndoLog) {
        undo = nil
        guard let habit = habits.first(where: { $0.id == change.habitID }) else { return }
        if change.wasLogged {
            habit.removeLog(on: change.day, in: modelContext)
        } else {
            habit.log(on: change.day, in: modelContext)
        }
    }

    private func delete(_ habit: Habit) {
        if undo?.habitID == habit.id { undo = nil }
        HabitLifecycle.delete(habit, in: modelContext, timer: timerCenter, notifications: notifications)
        pendingDelete = nil
    }

    private func refreshHealth() async {
        Haptics.light()
        await health.syncHealthKitHabits(in: modelContext)
    }
}

// MARK: - Undo

/// The last change made from the grid, kept while its toast shows (four
/// seconds, or until swiped away) so the toast can take it back.
struct UndoLog: Equatable {
    let id = UUID()
    let habitID: UUID
    let title: String
    let color: Color
    let day: Date
    /// True when the change added a log; false when it removed one.
    let wasLogged: Bool
    /// Set when this log finished a perfect day, so the toast says so.
    var completesDay = false

    init(habit: Habit, day: Date, wasLogged: Bool) {
        self.habitID = habit.id
        self.title = habit.title
        self.color = habit.color
        self.day = day.startOfDay
        self.wasLogged = wasLogged
    }

    /// A check for a log, the way back for one taken away.
    var icon: String {
        wasLogged ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill"
    }

    /// The habit's color, or green once the day is perfect, as the week
    /// strip's ring closes.
    var tint: Color { completesDay ? AppColors.success : color }

    var message: String {
        if completesDay { return "Perfect day" }
        let when = day.isToday ? "" : " for \(day.relativeDayName)"
        return wasLogged ? "\(title) logged\(when)" : "\(title) unlogged\(when)"
    }
}

// MARK: - Sheet Routing

enum HabitSheet: Identifiable {
    case edit(Habit)
    case timer(Habit)

    var id: String {
        switch self {
        case .edit(let h):   return "edit-\(h.id.uuidString)"
        case .timer(let h):  return "timer-\(h.id.uuidString)"
        }
    }
}

#Preview {
    let notifications = NotificationService()
    return NavigationStack {
        ContentView()
            .background { AppBackground() }
    }
    .modelContainer(for: [Habit.self, HabitCompletion.self], inMemory: true)
    .environment(HealthKitService())
    .environment(notifications)
    .environment(TimerCenter(notifications: notifications))
    .environment(DayTracker())
}
