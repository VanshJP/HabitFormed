import SwiftUI
import SwiftData

/// Habit detail sheet for logging and reviewing history.
/// Reachable via a single tap on a tile; complements the long-press shortcut.
struct HabitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerCenter.self) private var timerCenter
    @Environment(DayTracker.self) private var dayTracker

    let habit: Habit

    @State private var showingTimer = false
    @State private var showMonthChart = false

    var body: some View {
        // Re-render at midnight so the toggle button label flips back
        // to "Log Today" when the day rolls over.
        let _ = dayTracker.today

        return NavigationStack {
            ZStack {
                AppBackground(style: .subtle).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        heroCard
                        statsRow
                        if showMonthChart {
                            monthActivityChart
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        logButton
                        if habit.timerDurationSeconds > 0 { timerButton }
                        historySection
                    }
                    .padding(20)
                }
            }
            .navigationTitle(habit.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showingTimer) {
                TimerView(habit: habit)
            }
        }
    }

    // MARK: - Sections

    private var heroCard: some View {
        VStack(spacing: 16) {
            Image(systemName: habit.symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Circle().fill(habit.color.opacity(0.4)))

            Text(habit.title)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            WeekDotsView(completionDates: habit.completionDates)
                .scaleEffect(1.6)
                .padding(.vertical, 6)

            scheduleFooter
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard(cornerRadius: 22, tint: habit.color.opacity(0.18))
    }

    // Cadence pill under the week dots; interval habits also get a
    // next-due status line beneath it.
    @ViewBuilder
    private var scheduleFooter: some View {
        VStack(spacing: 6) {
            Text(habit.scheduleLabel.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.07)))

            if habit.frequency == .interval {
                nextDueCaption
            }
        }
    }

    private var nextDueCaption: some View {
        let status = nextDueStatus
        return Text(status.text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(status.isUrgent ? habit.color : Color.white.opacity(0.45))
    }

    /// Copy for the interval next-due line; urgent = due today / overdue.
    private var nextDueStatus: (text: String, isUrgent: Bool) {
        switch habit.daysUntilDue {
        case nil:
            return ("Log to start the cycle", false)
        case 0?:
            return ("Due today", true)
        case let d? where d < 0:
            return ("\(-d) days overdue", true)
        case let d?:
            return ("Next log in \(d) days", false)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.light()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showMonthChart.toggle()
                }
            } label: {
                VStack(spacing: 4) {
                    Text("\(habit.displayStreak)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 3) {
                        Text("STREAK")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.2)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .rotationEffect(.degrees(showMonthChart ? -180 : 0))
                    }
                    .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .glassCard(cornerRadius: 16, tint: AppColors.glassTintAccent)
            }
            .buttonStyle(.plain)
            statTile(value: "\(totalCompletions)", label: "TOTAL", color: .white)
            statTile(value: thisWeekStat, label: "THIS WK", color: habit.color)
        }
    }

    /// THIS WK stat. Weekly habits show progress toward the target.
    private var thisWeekStat: String {
        habit.frequency == .weekly
            ? "\(habit.completionsThisWeek)/\(habit.weeklyTarget)"
            : "\(habit.completionsThisWeek)"
    }

    private func statTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 16, tint: AppColors.glassTintAccent)
    }

    private var logButton: some View {
        Button(action: toggleToday) {
            HStack(spacing: 10) {
                Image(systemName: habit.isCompletedToday ? "checkmark.seal.fill" : "plus.circle.fill")
                    .font(.title3)
                Text(habit.isCompletedToday ? "Logged Today (Tap to Undo)" : "Log Today")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: habit.isCompletedToday
                                ? [habit.color.opacity(0.55), habit.color.opacity(0.35)]
                                : [habit.color, habit.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: habit.color.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var timerButton: some View {
        Button {
            Haptics.medium()
            showingTimer = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: timerCenter.habitID == habit.id && timerCenter.isRunning
                      ? "waveform" : "timer")
                    .font(.title3)
                Text(timerButtonLabel)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(habit.color.opacity(0.6), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var timerButtonLabel: String {
        if timerCenter.habitID == habit.id {
            let s = timerCenter.remainingSeconds
            let prefix = timerCenter.isRunning ? "Open" : "Resume"
            return String(format: "\(prefix) %d:%02d Timer", s / 60, s % 60)
        }
        return "Start \(habit.timerDurationSeconds / 60) min Timer"
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            GlassSectionHeader("History", icon: "clock.arrow.circlepath")

            if groupedHistory.isEmpty {
                Text("No completions yet. Log today to start your streak.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .glassCard(cornerRadius: 16, tint: AppColors.glassTintAccent)
            } else {
                ForEach(groupedHistory) { group in
                    HabitHistoryGroup(title: group.title, completions: group.items, accent: habit.color) { completion in
                        delete(completion)
                    }
                }
            }
        }
    }

    // MARK: - Month Activity Chart

    private var monthActivityChart: some View {
        let days = Date.trailingDays(42)
        let completed = Set(habit.completionDates.map { $0.startOfDay })
        let loggedCount = days.filter { completed.contains($0) }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(loggedCount)")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("of \(days.count) days")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text("PAST 6 WEEKS")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.35))
            }

            ActivityHeatMap(
                completionDates: habit.completionDates,
                accent: habit.color,
                weeks: 6,
                cellSpacing: 4,
                cornerRadius: 4,
                cellSize: 22
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .glassCard(cornerRadius: 16, tint: AppColors.glassTintAccent)
    }

    // MARK: - Data

    private var sortedCompletions: [HabitCompletion] {
        (habit.completions ?? []).sorted { $0.date > $1.date }
    }

    private var totalCompletions: Int { sortedCompletions.count }

    private var groupedHistory: [HistorySection] {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        let groups = Dictionary(grouping: sortedCompletions) { formatter.string(from: $0.date) }
        var sections: [HistorySection] = []
        for (title, items) in groups {
            let sortedItems = items.sorted { $0.date > $1.date }
            sections.append(HistorySection(title: title, items: sortedItems))
        }
        return sections.sorted { ($0.items.first?.date ?? .distantPast) > ($1.items.first?.date ?? .distantPast) }
    }

    // MARK: - Actions

    private func toggleToday() {
        if let existing = habit.todayCompletion {
            Haptics.warning()
            modelContext.delete(existing)
        } else {
            Haptics.success()
            SoundEffects.logChime()
            let new = HabitCompletion(date: Date(), value: habit.targetValue, habit: habit)
            modelContext.insert(new)
        }
        try? modelContext.save()
    }

    private func delete(_ completion: HabitCompletion) {
        Haptics.warning()
        modelContext.delete(completion)
        try? modelContext.save()
    }
}

private struct HistorySection: Identifiable {
    let title: String
    let items: [HabitCompletion]
    var id: String { title }
}
