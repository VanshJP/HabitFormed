import SwiftUI
import SwiftData

/// The long view, in two sections. Overview: the perfect-day numbers, this
/// week with its recap, a 12-week consistency map and every habit's streak.
/// Log: day by day, where each day can be sent as a report.
struct HistoryView: View {
    var onShareReport: (Date) -> Void = { _ in }
    var onShareWeek: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(DayTracker.self) private var dayTracker

    @Query(sort: [SortDescriptor(\HabitCompletion.date, order: .reverse)])
    private var completions: [HabitCompletion]

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @State private var section: HistorySection = .overview
    @State private var detailHabit: Habit?
    /// How many days of the log are drawn; "Show earlier days" adds a month.
    @State private var logDays = 30

    private static let mapWeeks = 12

    var body: some View {
        // Re-render at midnight so "Today" headers and stats stay correct.
        let _ = dayTracker.today

        return PageScrollView {
            VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                // A tab with sections opens on its picker rather than a title.
                SectionPicker(
                    sections: HistorySection.allCases,
                    selection: $section,
                    label: { $0.title }
                )
                .padding(.top, 4)

                if completions.isEmpty && habits.isEmpty {
                    EmptyStateCard(
                        icon: "calendar",
                        title: "No logs yet",
                        message: "Log something on Today and it shows up here."
                    )
                } else {
                    switch section {
                    case .overview:
                        overview
                        streaksSection
                    case .log:
                        log
                    }
                }
            }
            .pageContentInsets()
        }
        .sheet(item: $detailHabit) { habit in
            HabitDetailView(habit: habit)
        }
    }

    // MARK: - Overview

    private var overview: some View {
        let tracks = habits.map(\.track)
        let summaries = DayLedger.summaries(endingOn: dayTracker.today, count: Self.mapWeeks * 7, tracks: tracks)
        let byDay = Dictionary(uniqueKeysWithValues: summaries.map { ($0.date, $0) })
        let perfect = summaries.filter(\.isPerfect).count

        return VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
            GlassCard {
                HStack(spacing: 0) {
                    StatPair(value: "\(DayLedger.perfectStreak(tracks: tracks))", label: "Perfect streak", valueFont: .metricValue)
                        .frame(maxWidth: .infinity)
                    statDivider
                    StatPair(value: "\(DayLedger.bestPerfectStreak(tracks: tracks))", label: "Best", valueFont: .metricValue)
                        .frame(maxWidth: .infinity)
                    statDivider
                    StatPair(value: "\(completions.count)", label: "All-time logs", valueFont: .metricValue)
                        .frame(maxWidth: .infinity)
                }
            }

            thisWeek(Array(summaries.suffix(7)))

            GlassSection("Last 12 weeks", meta: perfect == 1 ? "1 perfect day" : "\(perfect) perfect days") {
                GlassCard {
                    ConsistencyHeatMap(summaries: byDay, weeks: Self.mapWeeks)
                }
            }
        }
    }

    /// The last seven days in two numbers, with the way to send them as the
    /// Sunday recap card.
    private func thisWeek(_ days: [DaySummary]) -> some View {
        let perfect = days.filter(\.isPerfect).count
        let logged = days.reduce(0) { $0 + $1.done }
        let expected = days.reduce(0) { $0 + $1.expected }

        return GlassSection("Last 7 days") {
            GlassCard {
                HStack(spacing: 0) {
                    StatPair(value: "\(perfect) of 7", label: "Perfect days", valueFont: .metricValue)
                        .frame(maxWidth: .infinity)
                    statDivider
                    StatPair(value: "\(logged) of \(expected)", label: "Logged", valueFont: .metricValue)
                        .frame(maxWidth: .infinity)
                }
            }
        } accessory: {
            Button(action: onShareWeek) {
                HeaderLinkLabel("Share recap", icon: "square.and.arrow.up")
            }
            .buttonStyle(.textLink)
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 0.5, height: 32)
    }

    // MARK: - Streaks

    @ViewBuilder
    private var streaksSection: some View {
        if !habits.isEmpty {
            GlassSection("Streaks") {
                GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                    ForEach(habitsByStreak) { habit in
                        Button {
                            Haptics.light()
                            detailHabit = habit
                        } label: {
                            ListRowLabel(icon: habit.symbol, tint: habit.color, title: habit.title) {
                                Text(streakText(habit))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(habit.displayStreak > 0 ? AnyShapeStyle(.white) : AnyShapeStyle(.tertiary))
                            }
                        }
                        .buttonStyle(RowPressStyle())
                    }
                }
            }
        }
    }

    private var habitsByStreak: [Habit] {
        habits.sorted { $0.displayStreak > $1.displayStreak }
    }

    private func streakText(_ habit: Habit) -> String {
        let streak = habit.displayStreak
        return "\(streak) \(habit.streakUnit(for: streak))"
    }

    // MARK: - Log

    @ViewBuilder
    private var log: some View {
        let groups = grouped
        let shown = groups.prefix { $0.date >= dayTracker.today.adding(days: -logDays) }

        if groups.isEmpty {
            EmptyStateCard(
                icon: "list.bullet",
                title: "No logs yet",
                message: "Slide a tile on Today and the day shows up here."
            )
        } else {
            VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                ForEach(Array(shown)) { group in
                    daySection(group)
                }

                if shown.count < groups.count {
                    Button {
                        Haptics.light()
                        logDays += 30
                    } label: {
                        Text("Show earlier days")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: AppLayout.minHitTarget)
                    }
                    .buttonStyle(.textLink)
                }
            }
        }
    }

    private func daySection(_ group: DayGroup) -> some View {
        GlassSection(group.date.relativeDayName) {
            GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                ForEach(group.completions) { completion in
                    CompletionRow(completion: completion, onDelete: { delete(completion) })
                }
            }
        } accessory: {
            Button {
                onShareReport(group.date)
            } label: {
                HeaderLinkLabel("Share", icon: "square.and.arrow.up")
            }
            .buttonStyle(.textLink)
            .accessibilityLabel("Share the report for \(group.date.relativeDayName)")
        }
    }

    // MARK: - Aggregation

    private var grouped: [DayGroup] {
        let cal = Calendar.current
        let buckets = Dictionary(grouping: completions) { cal.startOfDay(for: $0.date) }
        return buckets
            .map { DayGroup(date: $0.key, completions: $0.value.sorted { $0.loggedAt > $1.loggedAt }) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Actions

    private func delete(_ completion: HabitCompletion) {
        Haptics.warning()
        modelContext.delete(completion)
        try? modelContext.save()
    }
}

// MARK: - Sections

nonisolated enum HistorySection: String, CaseIterable, Identifiable, Sendable {
    case overview
    case log

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .log: return "Log"
        }
    }
}

// MARK: - Day group

struct DayGroup: Identifiable {
    let date: Date
    let completions: [HabitCompletion]
    var id: Date { date }
}
