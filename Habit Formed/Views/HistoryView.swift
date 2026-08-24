import SwiftUI
import SwiftData

/// Lifetime log feed: a stats strip plus one day-grouped timeline card.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DayTracker.self) private var dayTracker

    @Query(sort: [SortDescriptor(\HabitCompletion.date, order: .reverse)])
    private var completions: [HabitCompletion]

    var body: some View {
        // Re-render at midnight so "Today"/"Yesterday" headers and
        // today/week stats stay correct.
        let _ = dayTracker.today

        return ZStack {
            AppBackground(style: .primary).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    statsStrip

                    if grouped.isEmpty {
                        emptyState
                    } else {
                        timelineHeader
                        timelineCard
                    }
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Stats strip

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statColumn(value: todayCount, label: "TODAY")
            columnDivider
            statColumn(value: weekCount, label: "THIS WEEK")
            columnDivider
            statColumn(value: completions.count, label: "ALL-TIME")
        }
        .padding(16)
        .glassCard(cornerRadius: 20, tint: AppColors.glassTintAccent)
    }

    private func statColumn(value: Int, label: String) -> some View {
        VStack(spacing: 5) {
            Text("\(value)")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1)
            .frame(maxHeight: 34)
    }

    // MARK: - Timeline

    private var timelineHeader: some View {
        HStack {
            Text("TIMELINE")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var timelineCard: some View {
        let groups = Array(grouped.prefix(60))
        return VStack(alignment: .leading, spacing: 22) {
            ForEach(groups) { group in
                daySection(group)
            }
        }
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 20, tint: AppColors.glassTintAccent)
    }

    private func daySection(_ group: DayGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(headerTitle(for: group.date))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text("\(group.completions.count)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.white.opacity(0.08)))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(group.completions.enumerated()), id: \.element.id) { index, completion in
                    CompletionRow(completion: completion, onDelete: { delete(completion) })
                    if index < group.completions.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.leading, 56)
                    }
                }
            }
        }
    }

    /// "Today" / "Yesterday" / short weekday-date like "FRI AUG 21".
    private func headerTitle(for date: Date) -> String {
        if date.isToday { return "TODAY" }
        if date.isYesterday { return "YESTERDAY" }
        let cal = Calendar.current
        let weekday = cal.shortWeekdaySymbols[cal.component(.weekday, from: date) - 1]
        let month = cal.shortMonthSymbols[cal.component(.month, from: date) - 1]
        return "\(weekday) \(month) \(cal.component(.day, from: date))".uppercased()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.4))
            Text("No logs yet")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("Log something on Home and it shows up here.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Aggregation

    private var todayCount: Int {
        completions.filter { $0.date.isToday }.count
    }

    private var weekCount: Int {
        let cal = Calendar.current
        return completions.filter {
            cal.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
    }

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
