import SwiftUI
import SwiftData

/// The long view: lifetime numbers, a 12-week consistency map, every habit's
/// streak, and a day-by-day log where each day can be sent as a report.
struct HistoryView: View {
    var onShareReport: (Date) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(DayTracker.self) private var dayTracker

    @Query(sort: [SortDescriptor(\HabitCompletion.date, order: .reverse)])
    private var completions: [HabitCompletion]

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @State private var detailHabit: Habit?
    /// How many days of the timeline are drawn; "Show more" adds a month.
    @State private var timelineDays = 30

    private static let mapWeeks = 12

    var body: some View {
        // Re-render at midnight so "Today" headers and stats stay correct.
        let _ = dayTracker.today

        return PageScrollView {
            VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                PageTitle(title: "History")

                if completions.isEmpty && habits.isEmpty {
                    EmptyStateCard(
                        icon: "calendar",
                        title: "No logs yet",
                        message: "Log something on Today and it shows up here."
                    )
                } else {
                    overview
                    streaksSection
                    timeline
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
        let days = Self.mapWeeks * 7
        let summaries = DayLedger.summaries(endingOn: dayTracker.today, count: days, tracks: tracks)
        let byDay = Dictionary(uniqueKeysWithValues: summaries.map { ($0.date, $0) })
        let perfect = summaries.filter(\.isPerfect).count

        return VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                StatTile(icon: "flame.fill", value: "\(DayLedger.perfectStreak(tracks: tracks))", label: "Perfect-day streak", tint: AppColors.warning)
                StatTile(icon: "trophy.fill", value: "\(DayLedger.bestPerfectStreak(tracks: tracks))", label: "Best streak", tint: AppColors.success)
                StatTile(icon: "calendar", value: "\(weekCount)", label: "Logs this week", tint: AppColors.info)
                StatTile(icon: "checkmark.circle.fill", value: "\(completions.count)", label: "All-time logs", tint: AppColors.brandBright)
            }

            GlassSection("Last 12 weeks", meta: perfect == 1 ? "1 perfect day" : "\(perfect) perfect days") {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ConsistencyHeatMap(summaries: byDay, weeks: Self.mapWeeks)
                        HStack(spacing: 6) {
                            Text("Less")
                            ForEach([0.09, 0.4, 0.7], id: \.self) { alpha in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(alpha < 0.1 ? Color.white.opacity(alpha) : AppColors.success.opacity(alpha))
                                    .frame(width: 12, height: 12)
                            }
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(AppColors.success)
                                .frame(width: 12, height: 12)
                            Text("Perfect")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private var weekCount: Int {
        let cal = Calendar.current
        return completions.filter {
            cal.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
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
                            ListRowLabel(
                                icon: habit.symbol,
                                tint: habit.color,
                                title: habit.title,
                                subtitle: habit.scheduleLabel
                            ) {
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text("\(habit.displayStreak)")
                                        .font(.statValue)
                                        .foregroundStyle(.white)
                                    Text(habit.streakUnitLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
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

    // MARK: - Timeline

    @ViewBuilder
    private var timeline: some View {
        let groups = grouped
        let shown = groups.prefix { $0.date >= dayTracker.today.adding(days: -timelineDays) }

        VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
            ForEach(Array(shown)) { group in
                daySection(group)
            }

            if shown.count < groups.count {
                Button {
                    Haptics.light()
                    timelineDays += 30
                } label: {
                    Text("Show earlier days")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: AppLayout.minHitTarget)
                }
                .buttonStyle(.textLink)
            }
        }
    }

    private func daySection(_ group: DayGroup) -> some View {
        GlassSection(headerTitle(for: group.date)) {
            GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                ForEach(group.completions) { completion in
                    CompletionRow(completion: completion, onDelete: { delete(completion) })
                }
            }
        } accessory: {
            HStack(spacing: 10) {
                HeaderMeta(group.completions.count == 1 ? "1 log" : "\(group.completions.count) logs")
                Button {
                    onShareReport(group.date)
                } label: {
                    HeaderLinkLabel("Share", icon: "square.and.arrow.up")
                }
                .buttonStyle(.textLink)
                .accessibilityLabel("Share the report for \(group.date.relativeDayName)")
            }
        }
    }

    /// "Today", "Yesterday", or "Mon, Oct 12".
    private func headerTitle(for date: Date) -> String {
        date.relativeDayName
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

// MARK: - Day group

struct DayGroup: Identifiable {
    let date: Date
    let completions: [HabitCompletion]
    var id: Date { date }
}
