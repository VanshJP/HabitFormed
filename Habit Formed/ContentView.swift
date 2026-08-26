import SwiftUI
import SwiftData

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

    @State private var sheet: HabitSheet?
    @State private var pendingDelete: Habit?
    @State private var selectedDate: Date = .now

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var isViewingToday: Bool {
        // Compare against `dayTracker.today` so a midnight rollover correctly
        // flips this from true → false (and the read-only banner appears).
        selectedDate.isSameDay(as: dayTracker.today)
    }

    var body: some View {
        // Re-render when the calendar day rolls over so `isCompletedToday`
        // checks (header counter, tile state) reflect reality at midnight.
        let _ = dayTracker.today

        return ZStack {
            AppBackground(style: .primary).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    HeaderView(
                        selectedDate: $selectedDate,
                        isViewingToday: isViewingToday,
                        completedCount: habits.filter { $0.isCompleted(on: selectedDate) }.count,
                        // Resting interval habits (countdown still running)
                        // aren't expected today, so keep them out of "X / Y".
                        totalHabits: habits.filter { !$0.isRestingToday }.count,
                        onResetToToday: { selectedDate = .now },
                        onAdd: onAdd
                    )
                    .padding(.horizontal, 4)

                    if habits.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(habits) { habit in
                                HabitTileView(
                                    habit: habit,
                                    selectedDate: selectedDate,
                                    isReadOnly: !isViewingToday,
                                    onTap:           { sheet = .detail(habit) },
                                    onLog:           { logCompletion(for: habit) },
                                    onEdit:          { sheet = .edit(habit) },
                                    onRequestDelete: { pendingDelete = habit },
                                    onStartTimer:    { sheet = .timer(habit) }
                                )
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
            .refreshable { await refreshHealth() }
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .edit(let h):   AddHabitView(habit: h)
            case .detail(let h): HabitDetailView(habit: h)
            case .timer(let h):  TimerView(habit: h)
            }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.title ?? "habit")?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let habit = pendingDelete { delete(habit) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
        .task {
            try? await health.requestAuthorization()
            await health.syncHealthKitHabits(in: modelContext)
            // Subscribe to HealthKit change notifications so the step
            // challenge & friends update in near real-time instead of
            // only on the 15s polling tick.
            health.startObservingHealthKitHabits(in: modelContext)

            // Reminder scheduling. Permission is requested lazily when a
            // reminder toggle is turned on (AddHabitView), not at launch.
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

    // MARK: - Subviews

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

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text("No habits yet")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("Tap + to add your first one.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    // MARK: - Actions

    private func logCompletion(for habit: Habit) {
        // Logging only ever applies to today; the tile suppresses the
        // slide/contextMenu when browsing a past date, this is a fallback.
        guard isViewingToday, !habit.isCompletedToday else { return }
        let completion = HabitCompletion(date: Date(), value: habit.targetValue, habit: habit)
        modelContext.insert(completion)
        try? modelContext.save()
    }

    private func delete(_ habit: Habit) {
        Haptics.error()
        // Tear down any active timer for this habit BEFORE the model
        // is deleted so `TimerCenter.stop()` can dismiss the Live
        // Activity while the snapshot still references a real habit.
        if timerCenter.habitID == habit.id {
            timerCenter.stop()
        }
        // Same belt-and-braces for reminders; the signature change below
        // would resync anyway, but this doesn't depend on observers.
        notifications.cancelReminders(habitID: habit.id)
        modelContext.delete(habit)
        try? modelContext.save()
    }

    private func refreshHealth() async {
        Haptics.light()
        await health.syncHealthKitHabits(in: modelContext)
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
    return ContentView()
        .modelContainer(for: [Habit.self, HabitCompletion.self], inMemory: true)
        .environment(HealthKitService())
        .environment(notifications)
        .environment(TimerCenter(notifications: notifications))
        .environment(DayTracker())
}
