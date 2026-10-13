import SwiftUI
import SwiftData

/// One habit's page: today's log and note, the numbers, a calendar that fixes
/// history with a tap, and the month-by-month log. Opened by tapping a tile.
struct HabitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerCenter.self) private var timerCenter
    @Environment(NotificationService.self) private var notifications
    @Environment(DayTracker.self) private var dayTracker

    let habit: Habit

    @State private var showingTimer = false
    @State private var showingEdit = false
    @State private var confirmDelete = false
    @State private var calendarWeeks = 12
    /// Set by Delete. The habit goes once this page is off screen, because a
    /// page still drawing would read a model whose data no longer exists.
    @State private var deleteOnClose = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        // Re-render at midnight so the log button flips back to "Log today".
        let _ = dayTracker.today

        return NavigationStack {
            PageScrollView {
                VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                    hero
                    statsRow
                    todaySection
                    calendarSection
                    historySection
                }
                .padding(.horizontal, AppLayout.pageHorizontal)
                .padding(.bottom, AppLayout.pageBottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { AppBackground(style: .subtle) }
            .navigationTitle(habit.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit", systemImage: "pencil") { showingEdit = true }
                        Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                }
            }
            .onDisappear {
                guard deleteOnClose else { return }
                HabitLifecycle.delete(habit, in: modelContext, timer: timerCenter, notifications: notifications)
            }
            .sheet(isPresented: $showingTimer) {
                TimerView(habit: habit)
            }
            .sheet(isPresented: $showingEdit) {
                AddHabitView(habit: habit)
            }
            .alert("Delete this habit?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    deleteOnClose = true
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes \(habit.title) and its history.")
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            IconChip(icon: habit.symbol, tint: habit.color, size: 56)

            Text(habit.title)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                StatusPill(text: habit.scheduleLabel, color: .white, glyph: .icon(habit.trackKind.symbol), textColor: .secondary)
                if habit.frequency == .interval {
                    let status = nextDueStatus
                    StatusPill(
                        text: status.text,
                        color: status.isUrgent ? habit.color.glyphTone : .white,
                        glyph: .dot,
                        textColor: status.isUrgent ? nil : Color.secondary
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    /// Copy for the interval next-due pill; urgent means due or overdue.
    private var nextDueStatus: (text: String, isUrgent: Bool) {
        switch habit.daysUntilDue {
        case nil:
            return ("Log to start the cycle", false)
        case 0?:
            return ("Due today", true)
        case let d? where d < 0:
            return (d == -1 ? "1 day overdue" : "\(-d) days overdue", true)
        case let d?:
            return (d == 1 ? "Next log tomorrow" : "Next log in \(d) days", false)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(icon: "flame.fill", value: "\(habit.displayStreak)", label: "\(habit.streakUnitLabel.capitalized) streak", tint: AppColors.warning)
            StatTile(icon: "checkmark.circle.fill", value: "\(totalCompletions)", label: "Total logs", tint: habit.color.glyphTone)
            StatTile(icon: "calendar", value: thisWeekStat, label: "This week", tint: AppColors.info)
        }
    }

    /// Weekly habits show progress toward the target.
    private var thisWeekStat: String {
        habit.frequency == .weekly
            ? "\(habit.completionsThisWeek)/\(habit.weeklyTarget)"
            : "\(habit.completionsThisWeek)"
    }

    // MARK: - Today

    private var todaySection: some View {
        GlassSection("Today") {
            VStack(spacing: 12) {
                if let entry = habit.todayCompletion {
                    loggedCard(entry)
                } else {
                    GlassButton(title: "Log today", icon: "checkmark", style: .primary, size: .large, fullWidth: true) {
                        Haptics.success()
                        SoundEffects.logChime()
                        habit.log(in: modelContext)
                    }
                }

                if habit.timerDurationSeconds > 0 && !habit.isCompletedToday {
                    GlassButton(title: timerButtonLabel, icon: timerIcon, style: .secondary, size: .medium, fullWidth: true) {
                        Haptics.medium()
                        showingTimer = true
                    }
                }
            }
        }
    }

    private func loggedCard(_ entry: HabitCompletion) -> some View {
        GlassCard(tint: AppColors.featuredTint(habit.color)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(habit.color.glyphTone)
                    Text("Logged at \(entry.loggedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Undo") {
                        Haptics.warning()
                        habit.removeLog(on: Date(), in: modelContext)
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: AppLayout.minHitTarget)
                    .buttonStyle(.textLink)
                }

                TextField(
                    "",
                    text: Binding(get: { entry.note }, set: { entry.note = $0 }),
                    prompt: Text("Add a note: what did you do?").foregroundStyle(.white.opacity(0.4)),
                    axis: .vertical
                )
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(1...4)
                .focused($noteFocused)
                .submitLabel(.done)
                .inputWell(isFocused: noteFocused)
                .onChange(of: noteFocused) { _, focused in
                    if !focused { try? modelContext.save() }
                }

                Text("Notes show up in History and on your daily report.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timerIcon: String {
        timerCenter.habitID == habit.id && timerCenter.isRunning ? "waveform" : "timer"
    }

    private var timerButtonLabel: String {
        if timerCenter.habitID == habit.id {
            let s = timerCenter.remainingSeconds
            let prefix = timerCenter.isRunning ? "Open timer" : "Resume timer"
            return String(format: "\(prefix) · %d:%02d", s / 60, s % 60)
        }
        return "Start \(habit.timerDurationSeconds / 60) min timer"
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        let completed = habit.completionDays
        let days = Date.trailingDays(calendarWeeks * 7)
        let logged = days.filter { completed.contains($0) }.count

        return GlassSection("Calendar", meta: "\(logged) of last \(days.count) days") {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    ActivityHeatMap(
                        completionDates: habit.completionDates,
                        accent: habit.color,
                        weeks: calendarWeeks,
                        cellSpacing: 4,
                        cornerRadius: 4,
                        onToggleDay: toggle
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Tap a day to add a forgotten log or remove a wrong one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func toggle(_ day: Date) {
        if habit.isCompleted(on: day) {
            Haptics.warning()
            habit.removeLog(on: day, in: modelContext)
        } else {
            Haptics.success()
            habit.log(on: day, in: modelContext)
        }
    }

    // MARK: - History

    private var historySection: some View {
        GlassSection("History", meta: totalCompletions == 1 ? "1 log" : "\(totalCompletions) logs") {
            if groupedHistory.isEmpty {
                EmptyStateCard(
                    icon: "clock.arrow.circlepath",
                    title: "No logs yet",
                    message: "Log today to start your streak."
                )
            } else {
                VStack(alignment: .leading, spacing: AppLayout.listSpacing) {
                    ForEach(groupedHistory) { group in
                        HabitHistoryGroup(title: group.title, completions: group.items, accent: habit.color) { completion in
                            delete(completion)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data

    private var sortedCompletions: [HabitCompletion] {
        (habit.completions ?? []).sorted { $0.date > $1.date }
    }

    private var totalCompletions: Int { habit.completions?.count ?? 0 }

    private var groupedHistory: [HistorySection] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: sortedCompletions) { entry in
            calendar.dateInterval(of: .month, for: entry.date)?.start ?? entry.date.startOfDay
        }
        return groups
            .map { month, items in
                HistorySection(
                    month: month,
                    title: month.formatted(.dateTime.month(.wide).year()),
                    items: items.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.month > $1.month }
    }

    // MARK: - Actions

    private func delete(_ completion: HabitCompletion) {
        Haptics.warning()
        modelContext.delete(completion)
        try? modelContext.save()
    }
}

private struct HistorySection: Identifiable {
    let month: Date
    let title: String
    let items: [HabitCompletion]
    var id: Date { month }
}
