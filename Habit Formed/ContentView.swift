import SwiftUI
import SwiftData

/// The Today tab: a header with the perfect-day streak, a week strip to jump
/// between recent days, the day's progress with the report button, and the
/// habit grid.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HealthKitService.self) private var health
    @Environment(NotificationService.self) private var notifications
    @Environment(TimerCenter.self) private var timerCenter
    @Environment(DayTracker.self) private var dayTracker

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    var onAdd: () -> Void = {}
    var onShareReport: (Date) -> Void = { _ in }

    @State private var sheet: HabitSheet?
    @State private var pendingDelete: Habit?
    @State private var selectedDate: Date = .now
    /// The last day the week strip shows; nil keeps it on today. Only the
    /// calendar and "Today" move it, so tapping a strip day never slides the
    /// strip under the finger.
    @State private var stripAnchor: Date?
    @State private var showDatePicker = false
    @State private var showArrange = false
    @State private var undo: UndoLog?
    @State private var celebration = 0

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var isViewingToday: Bool {
        // Against `dayTracker.today` so a midnight rollover flips this.
        selectedDate.isSameDay(as: dayTracker.today)
    }

    var body: some View {
        // Re-render when the calendar day rolls over so today's state
        // (header counter, tile state) reflects reality at midnight.
        let _ = dayTracker.today
        return lifecycle(presentations(page))
    }

    // MARK: - Page

    private var page: some View {
        let tracks = habits.map(\.track)
        let week = DayLedger.summaries(endingOn: stripEnd, count: 7, tracks: tracks)
        let todayIsPerfect = DayLedger.summary(on: dayTracker.today, tracks: tracks).isPerfect
        let streak = DayLedger.perfectStreak(tracks: tracks)

        return PageScrollView {
            VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                topBar(streak: streak, todayIsPerfect: todayIsPerfect)

                if habits.isEmpty {
                    EmptyStateCard(
                        icon: "circle.hexagongrid",
                        title: "No habits yet",
                        message: "Pick a template or start from scratch. Slide a tile to log it each day.",
                        buttonTitle: "Add a habit",
                        buttonAction: onAdd
                    )
                } else {
                    WeekStrip(summaries: week, selectedDate: $selectedDate)

                    // Names the day the grid shows once it is not today.
                    GlassSection(isViewingToday ? "Habits" : selectedDate.relativeDayName) {
                        grid
                    } accessory: {
                        HStack(spacing: 14) {
                            if !isViewingToday {
                                Button {
                                    Haptics.selection()
                                    backToToday()
                                } label: {
                                    HeaderLinkLabel("Today", icon: "arrow.uturn.forward")
                                }
                                .buttonStyle(.textLink)
                            }
                            Button {
                                onShareReport(selectedDate)
                            } label: {
                                HeaderLinkLabel("Share report", icon: "square.and.arrow.up")
                            }
                            .buttonStyle(.textLink)
                        }
                    }
                }
            }
            .pageContentInsets()
        }
        .refreshable { await refreshHealth() }
        .overlay(alignment: .top) { undoToast }
        .overlay {
            if celebration > 0 {
                ConfettiView(origin: UnitPoint(x: 0.5, y: 0.2))
                    .id(celebration)
                    .ignoresSafeArea()
            }
        }
        .motion(AppMotion.settle, value: undo?.id)
        .onChange(of: todayIsPerfect) { wasPerfect, isPerfect in
            // Celebrate the log that finishes the day, never a page load.
            guard isPerfect, !wasPerfect, isViewingToday else { return }
            Haptics.success()
            celebration += 1
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(habits) { habit in
                HabitTileView(
                    habit: habit,
                    selectedDate: selectedDate,
                    isPastDay: !isViewingToday,
                    onTap: { sheet = .detail(habit) },
                    onLog: { logToday(habit) },
                    onUndoToday: { undoToday(habit) },
                    onTogglePastDay: { togglePastDay(habit) },
                    onEdit: { sheet = .edit(habit) },
                    onArrange: { showArrange = true },
                    onRequestDelete: { pendingDelete = habit },
                    onStartTimer: { sheet = .timer(habit) }
                )
            }
        }
    }

    @ViewBuilder
    private var undoToast: some View {
        if let undo {
            UndoToast(message: undo.message, tint: undo.tint) { revert(undo) }
                .padding(.horizontal, AppLayout.pageHorizontal)
                .padding(.top, 4)
                .readableColumn()
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: undo.id) {
                    try? await Task.sleep(for: .seconds(4))
                    if self.undo?.id == undo.id { self.undo = nil }
                }
        }
    }

    // MARK: - Presentations

    private func presentations<V: View>(_ content: V) -> some View {
        content
            .sheet(item: $sheet) { item in
                switch item {
                case .edit(let habit): AddHabitView(habit: habit)
                case .detail(let habit): HabitDetailView(habit: habit)
                case .timer(let habit): TimerView(habit: habit)
                }
            }
            .sheet(isPresented: $showDatePicker, onDismiss: anchorStrip) {
                DateBrowserSheet(selectedDate: $selectedDate)
                    .presentationDetents([.medium, .large])
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
    }

    // MARK: - Lifecycle

    private func lifecycle<V: View>(_ content: V) -> some View {
        content
            .task {
                try? await health.requestAuthorization()
                await health.syncHealthKitHabits(in: modelContext)
                // HealthKit change notifications keep health tiles near
                // real-time instead of waiting on the polling tick.
                health.startObservingHealthKitHabits(in: modelContext)

                // Permission is requested lazily when a reminder is turned on.
                await notifications.syncReminders(for: habits)
            }
            .onChange(of: reminderSignature) { _, _ in
                Task { await notifications.syncReminders(for: habits) }
            }
            .task(id: "health-sync") {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(15))
                    guard !Task.isCancelled else { break }
                    await health.syncHealthKitHabits(in: modelContext)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    dayTracker.refresh()
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
    private func topBar(streak: Int, todayIsPerfect: Bool) -> some View {
        HStack(alignment: .center) {
            Button {
                Haptics.light()
                showDatePicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(monthTitle)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: AppLayout.minHitTarget)
                .contentShape(.rect)
            }
            .buttonStyle(GlassPressStyle())
            .accessibilityLabel("\(monthTitle), pick a date")

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                // The flame earns its place: with no run going it is only noise.
                if streak > 0 {
                    StreakChip(streak: streak, doneToday: todayIsPerfect)
                }

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(GlassPressStyle())
                .accessibilityLabel("Add habit")

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

    private func backToToday() {
        selectedDate = .now
        stripAnchor = nil
    }

    // MARK: - Reminder signature

    /// Order-insensitive fingerprint of every habit field that reminder
    /// scheduling depends on. Includes completion counts so logging or
    /// removing a log re-anchors interval chains and weekly bodies.
    private var reminderSignature: String {
        habits
            .map { habit in
                [
                    habit.id.uuidString,
                    String(habit.reminderEnabled),
                    "\(habit.reminderHour):\(habit.reminderMinute)",
                    habit.frequencyRaw,
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
        undo = UndoLog(habit: habit, day: Date(), wasLogged: true)
    }

    private func undoToday(_ habit: Habit) {
        Haptics.warning()
        habit.removeLog(on: Date(), in: modelContext)
    }

    /// Past days are fixed with one tap rather than a slide: a forgotten log
    /// is the most common correction, and the toast offers the way back.
    private func togglePastDay(_ habit: Habit) {
        let day = selectedDate
        if habit.isCompleted(on: day) {
            Haptics.warning()
            habit.removeLog(on: day, in: modelContext)
            undo = UndoLog(habit: habit, day: day, wasLogged: false)
        } else {
            Haptics.success()
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

/// The last change made from the grid, kept for four seconds so the toast can
/// take it back.
struct UndoLog: Equatable {
    let id = UUID()
    let habitID: UUID
    let title: String
    let tint: Color
    let day: Date
    /// True when the change added a log; false when it removed one.
    let wasLogged: Bool

    init(habit: Habit, day: Date, wasLogged: Bool) {
        self.habitID = habit.id
        self.title = habit.title
        self.tint = habit.color
        self.day = day.startOfDay
        self.wasLogged = wasLogged
    }

    var message: String {
        let when = day.isToday ? "" : " for \(day.relativeDayName)"
        return wasLogged ? "\(title) logged\(when)" : "\(title) unlogged\(when)"
    }
}

// MARK: - Sheet Routing

enum HabitSheet: Identifiable {
    case edit(Habit)
    case detail(Habit)
    case timer(Habit)

    var id: String {
        switch self {
        case .edit(let h):   return "edit-\(h.id.uuidString)"
        case .detail(let h): return "detail-\(h.id.uuidString)"
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
