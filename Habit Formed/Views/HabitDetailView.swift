import SwiftUI
import SwiftData

/// One habit's page: the streak, then its history as a calendar (the first
/// thing a tap on a tile is for, and where a tap fixes a day), today's log and
/// note, and the latest logs. Opened by tapping a tile.
struct HabitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerCenter.self) private var timerCenter
    @Environment(NotificationService.self) private var notifications
    @Environment(DayTracker.self) private var dayTracker
    @Environment(HealthKitService.self) private var health

    let habit: Habit

    @State private var showingTimer = false
    @State private var showingEdit = false
    @State private var confirmDelete = false
    @State private var pendingRemoval: HabitCompletion?
    private let calendarWeeks = 12
    /// The latest logs listed under the calendar, which already shows every day.
    private let recentCount = 10
    /// Set by Delete. The habit goes once this page is off screen, because a
    /// page still drawing would read a model whose data no longer exists.
    @State private var deleteOnClose = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        // Re-render at midnight so the log button flips back to "Log today".
        let _ = dayTracker.today

        return PageScrollView {
            VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                hero
                calendarSection
                todaySection
                recentSection
            }
            .padding(.horizontal, AppLayout.pageHorizontal)
            .padding(.bottom, AppLayout.pageBottom)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground(style: .subtle) }
        .pageTopBar(habit.title) { moreMenu }
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
        .confirmsLogRemoval($pendingRemoval, remove: delete)
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

    // MARK: - Hero

    /// The streak as the page's one big number, with the facts in one line
    /// under it. The name is in the navigation bar, so it is not repeated.
    private var hero: some View {
        let streak = habit.displayStreak

        return VStack(spacing: 8) {
            IconChip(icon: habit.symbol, tint: habit.color, size: 44)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(streak)")
                    .font(.displayNumeral)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(streak)))
                Text("\(habit.streakUnit(for: streak)) streak")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .motion(AppMotion.snap, value: streak)
            .accessibilityElement(children: .combine)

            Text(factLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let routine = routineLine {
                Text(routine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if healthLooksBlocked {
                // iOS never tells an app its Health access was declined, so a
                // reading stuck at zero is the only sign.
                Text("Stuck at 0? Check Settings › Privacy & Security › Health › Habit Formed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if habit.frequency == .interval {
                let status = nextDueStatus
                Text(status.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(status.isUrgent ? AnyShapeStyle(habit.color.glyphTone) : AnyShapeStyle(.secondary))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var healthLooksBlocked: Bool {
        guard habit.trackKind == .health, !habit.isCompletedToday else { return false }
        let values = habit.frequency == .weekly ? health.liveWeeklyValues : health.liveValues
        return (values[habit.source.rawValue] ?? 0) == 0
    }

    /// "Daily · 48 logs · 3 this week". Weekly habits count toward the target.
    private var factLine: String {
        let logs = totalCompletions == 1 ? "1 log" : "\(totalCompletions) logs"
        let week = habit.frequency == .weekly
            ? "\(habit.completionsThisWeek) of \(habit.weeklyTarget) this week"
            : "\(habit.completionsThisWeek) this week"
        return [habit.scheduleLabel, logs, week].joined(separator: " · ")
    }

    /// The usual log time and the reminder, said once: a learned reminder
    /// names the time it learned. The usual time is read once per render,
    /// since this page redraws every second while a timer runs.
    private var routineLine: String? {
        let usual = habit.usualLogMinute
        let usualLabel = usual.map { ReminderTime(minuteOfDay: $0).label }
        guard habit.reminderEnabled else { return usualLabel.map { "Usually logged around \($0)" } }
        let setTime = ReminderTime(hour: habit.reminderHour, minute: habit.reminderMinute).label
        guard habit.reminderLearnsTime, habit.trackKind != .health else {
            return usualLabel.map { "Reminds you at \(setTime), usually logged around \($0)" } ?? "Reminds you at \(setTime)"
        }
        guard let usual, let usualLabel else {
            return "Reminds you at \(setTime), learns your routine after \(ReminderTiming.minimumLogs) logs"
        }
        return "Reminds you at \(ReminderTiming.reminder(beforeTypical: usual).label), before your usual \(usualLabel)"
    }

    /// Copy for the interval next-due line; urgent means due or overdue.
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

    // MARK: - Today

    private var todaySection: some View {
        let section = VStack(spacing: 12) {
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
        return section.motion(AppMotion.settle, value: habit.isCompletedToday)
    }

    private func loggedCard(_ entry: HabitCompletion) -> some View {
        GlassCard(tint: AppColors.featuredTint(habit.color)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(habit.color.glyphTone)
                        .symbolEffect(.bounce, value: entry.id)
                    Text("Logged today at \(entry.loggedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Undo") {
                        Haptics.undo()
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

                    Text("Tap a day to add or remove its log")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func toggle(_ day: Date) {
        if habit.isCompleted(on: day) {
            Haptics.undo()
            habit.removeLog(on: day, in: modelContext)
        } else {
            Haptics.success()
            habit.log(on: day, in: modelContext)
        }
    }

    // MARK: - Recent

    @ViewBuilder
    private var recentSection: some View {
        let recent = Array(sortedCompletions.prefix(recentCount))
        if !recent.isEmpty {
            GlassSection("Recent logs") {
                HabitHistoryGroup(completions: recent, accent: habit.color) { completion in
                    pendingRemoval = completion
                }
            }
        }
    }

    // MARK: - More

    /// Edit and Delete, at the top bar's trailing end in the back button's
    /// glass.
    private var moreMenu: some View {
        Menu {
            Button("Edit", systemImage: "pencil") { Haptics.light(); showingEdit = true }
            Button("Delete", systemImage: "trash", role: .destructive) { Haptics.warning(); confirmDelete = true }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
                .headerGlass()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More")
    }

    // MARK: - Data

    private var sortedCompletions: [HabitCompletion] {
        (habit.completions ?? []).sorted { $0.date > $1.date }
    }

    private var totalCompletions: Int { habit.completions?.count ?? 0 }

    // MARK: - Actions

    private func delete(_ completion: HabitCompletion) {
        Haptics.undo()
        modelContext.delete(completion)
        try? modelContext.save()
    }
}
