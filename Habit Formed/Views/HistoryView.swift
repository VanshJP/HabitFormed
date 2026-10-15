import SwiftUI
import SwiftData

/// The long view, pushed from Today's clock: the perfect-day streak with the
/// week's recap, a 12-week map, every habit's streak, then the days. A day
/// opens in place to list its logs (long-press one to remove it) and share
/// its report.
struct HistoryView: View {
    var onShareReport: (Date) -> Void = { _ in }
    var onShareWeek: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(DayTracker.self) private var dayTracker

    @Query(sort: [SortDescriptor(\HabitCompletion.date, order: .reverse)])
    private var completions: [HabitCompletion]

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @State private var detailHabit: Habit?
    @State private var openDay: Date?
    @State private var pendingRemoval: HabitCompletion?
    /// How many days are listed; "Show earlier days" adds a month.
    @State private var logDays = 30

    private static let mapWeeks = 12

    var body: some View {
        // Re-render at midnight so "Today" names and stats stay correct.
        let _ = dayTracker.today

        return PageScrollView {
            VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                if completions.isEmpty && habits.isEmpty {
                    EmptyStateInline(icon: "calendar", message: "Slide a habit on Today and it shows up here.")
                        .padding(.top, 80)
                } else {
                    // One snapshot per habit for the whole page.
                    let tracks = habits.map(\.track)
                    overview(tracks)
                    streaksSection
                    daysSection(tracks)
                }
            }
            .pageContentInsets()
        }
        .background { AppBackground() }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .restoresNavigationBar()
        .confirmsLogRemoval($pendingRemoval, remove: delete)
        .navigationDestination(item: $detailHabit) { habit in
            HabitDetailView(habit: habit)
        }
    }

    // MARK: - Overview

    private func overview(_ tracks: [HabitTrack]) -> some View {
        let summaries = DayLedger.summaries(endingOn: dayTracker.today, count: Self.mapWeeks * 7, tracks: tracks)
        let byDay = Dictionary(uniqueKeysWithValues: summaries.map { ($0.date, $0) })
        let perfect = summaries.filter(\.isPerfect).count

        return VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
            HistoryHero(
                streak: DayLedger.perfectStreak(tracks: tracks),
                best: DayLedger.bestPerfectStreak(tracks: tracks),
                perfectLastWeek: summaries.suffix(7).filter(\.isPerfect).count,
                onShareRecap: onShareWeek
            )
            .padding(.top, 8)

            PatternsSection(habits: habits, tracks: tracks, completions: completions, today: dayTracker.today)

            GlassSection("Last 12 weeks", meta: perfect == 1 ? "1 perfect day" : "\(perfect) perfect days") {
                Panel {
                    VStack(alignment: .trailing, spacing: 12) {
                        ConsistencyHeatMap(summaries: byDay, weeks: Self.mapWeeks)
                        ConsistencyLegend()
                    }
                    .padding(AppLayout.tilePadding)
                }
            }
        }
    }

    // MARK: - Streaks

    @ViewBuilder
    private var streaksSection: some View {
        if !habits.isEmpty {
            GlassSection("Streaks") {
                Panel {
                    // Each streak once, not once per comparison.
                    let rows = habits.map { (habit: $0, streak: $0.displayStreak) }.sorted { $0.streak > $1.streak }
                    ForEach(rows, id: \.habit.id) { row in
                        Button {
                            Haptics.light()
                            detailHabit = row.habit
                        } label: {
                            ListRowLabel(icon: row.habit.symbol, tint: row.habit.color, title: row.habit.title) {
                                Text("\(row.streak) \(row.habit.streakUnit(for: row.streak))")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(row.streak > 0 ? AnyShapeStyle(.white) : AnyShapeStyle(.tertiary))
                            }
                        }
                        .buttonStyle(RowPressStyle())
                    }
                }
            }
        }
    }

    // MARK: - Days

    @ViewBuilder
    private func daysSection(_ tracks: [HabitTrack]) -> some View {
        let groups = grouped
        let shown = groups.prefix { $0.date >= dayTracker.today.adding(days: -logDays) }

        if !groups.isEmpty {
            GlassSection("Days") {
                VStack(spacing: 4) {
                    Panel(dividerInset: RowLayout.horizontalPadding) {
                        ForEach(Array(shown)) { group in
                            day(group, tracks: tracks)
                        }
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
    }

    /// The day's row, and while it is open its logs and its report, set a
    /// shade deeper so they read as inside the day.
    @ViewBuilder
    private func day(_ group: DayGroup, tracks: [HabitTrack]) -> some View {
        let isOpen = openDay == group.date
        Button {
            Haptics.light()
            withMotion(AppMotion.settle) { openDay = isOpen ? nil : group.date }
        } label: {
            DayRow(
                date: group.date,
                completions: group.completions,
                summary: DayLedger.summary(on: group.date, tracks: tracks, today: dayTracker.today),
                isOpen: isOpen
            )
        }
        .buttonStyle(RowPressStyle())

        if isOpen {
            ForEach(group.completions) { completion in
                CompletionRow(completion: completion, onDelete: { pendingRemoval = completion })
                    .background(Color.black.opacity(0.14))
            }
            Button {
                onShareReport(group.date)
            } label: {
                Label("Share report", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: AppLayout.minHitTarget)
                    .background(Color.black.opacity(0.14))
            }
            .buttonStyle(RowPressStyle())
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
        Haptics.undo()
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
