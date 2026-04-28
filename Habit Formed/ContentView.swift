import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HealthKitService.self) private var health
    @Environment(NotificationService.self) private var notifications

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @State private var sheet: HabitSheet?
    @State private var pendingDelete: Habit?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ZStack {
            AppBackground(style: .primary).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    HeaderView(
                        completedToday: habits.filter(\.isCompletedToday).count,
                        totalHabits: habits.count
                    )
                    .padding(.horizontal, 4)

                    if habits.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(habits) { habit in
                                HabitTileView(
                                    habit: habit,
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

            // Daily habit reminders.
            await notifications.refreshAuthorizationStatus()
            if !notifications.hasRequestedAuthorization {
                await notifications.requestAuthorization()
            }
            await notifications.rescheduleHabitReminders(habits)
        }
        .onChange(of: habits.map { "\($0.id)|\($0.reminderEnabled)|\($0.reminderHour):\($0.reminderMinute)|\($0.title)" }.joined()) { _, _ in
            Task { await notifications.rescheduleHabitReminders(habits) }
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
                Task {
                    await health.syncHealthKitHabits(in: modelContext)
                    health.startObservingHealthKitHabits(in: modelContext)
                }
            }
        }
    }

    // MARK: - Subviews

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
        guard !habit.isCompletedToday else { return }
        let completion = HabitCompletion(date: Date(), value: habit.targetValue, habit: habit)
        modelContext.insert(completion)
        try? modelContext.save()
    }

    private func delete(_ habit: Habit) {
        Haptics.error()
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
}
