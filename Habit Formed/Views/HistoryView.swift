import SwiftUI
import SwiftData
import Charts

/// Cross-habit log feed and analytics dashboard. Surfaces lifetime stats,
/// activity trends, weekday patterns, top habits, a consistency heatmap,
/// and a day-grouped feed of every completion across every habit.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\HabitCompletion.date, order: .reverse)])
    private var completions: [HabitCompletion]

    @Query(sort: [SortDescriptor(\Habit.sortOrder)])
    private var habits: [Habit]

    @State private var range: TimeRange = .month

    var body: some View {
        ZStack {
            AppBackground(style: .primary).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    rangePicker
                    activityChartCard
                    weekdayDistributionCard
                    if !topHabits.isEmpty { topHabitsCard }
                    heatmapCard

                    if grouped.isEmpty {
                        emptyState
                    } else {
                        feedHeader
                        ForEach(grouped) { group in
                            DayGroupView(group: group, onDelete: delete)
                        }
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

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(todayCount)")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.75)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("LOGS TODAY")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 0)

                streakMedallion
            }

            Divider().background(Color.white.opacity(0.08))

            HStack(spacing: 12) {
                miniStat(value: "\(weekCount)", label: "THIS WEEK", color: .teal, icon: "calendar")
                miniStat(value: "\(completions.count)", label: "ALL-TIME", color: .white, icon: "infinity")
                miniStat(value: "\(activeHabitCount)", label: "HABITS", color: AppColors.primary, icon: "circle.hexagongrid.fill")
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 22, tint: AppColors.glassTintAccent)
    }

    private var streakMedallion: some View {
        let color = AppColors.streakColor(for: longestStreak)
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.45), color.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle().strokeBorder(color.opacity(0.55), lineWidth: 0.6)
                )
                .frame(width: 84, height: 84)
                .shadow(color: color.opacity(0.35), radius: 10, y: 3)

            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
                Text("\(longestStreak)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("BEST")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }

    private func miniStat(value: String, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color.opacity(0.85))
                Text(value)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Range picker

    private var rangePicker: some View {
        HStack(spacing: 4) {
            ForEach(TimeRange.allCases) { option in
                rangePickerButton(option)
            }
        }
        .padding(5)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(Capsule())
    }

    private func rangePickerButton(_ option: TimeRange) -> some View {
        let isSelected = range == option
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                range = option
            }
        } label: {
            Text(option.label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.white.opacity(0.14))
                            .overlay(
                                Capsule().strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.4), .white.opacity(0.05)],
                                        startPoint: .top, endPoint: .bottom
                                    ),
                                    lineWidth: 0.6
                                )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Activity chart

    private var activityChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(
                title: "Activity",
                subtitle: "\(rangedCompletions.count) logs · \(activeDaysInRange) active \(activeDaysInRange == 1 ? "day" : "days")",
                icon: "chart.bar.xaxis"
            )

            Chart {
                ForEach(dailyBuckets) { bucket in
                    BarMark(
                        x: .value("Day", bucket.date, unit: .day),
                        y: .value("Logs", bucket.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.opacity(0.45)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }

                if averageInRange > 0.05 {
                    RuleMark(y: .value("Avg", averageInRange))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.white.opacity(0.35))
                        .annotation(position: .top, alignment: .trailing) {
                            Text(String(format: "avg %.1f/day", averageInRange))
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(0.6)
                                .foregroundStyle(.white.opacity(0.55))
                                .padding(.bottom, 2)
                        }
                }
            }
            .frame(height: 150)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: xStrideDays)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    AxisGridLine().foregroundStyle(.white.opacity(0.05))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    AxisGridLine().foregroundStyle(.white.opacity(0.05))
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20, tint: AppColors.glassTintAccent)
    }

    // MARK: - Weekday distribution

    private var weekdayDistributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(
                title: "Weekday Pattern",
                subtitle: peakWeekdaySubtitle,
                icon: "calendar"
            )

            Chart {
                ForEach(weekdayBuckets) { bucket in
                    BarMark(
                        x: .value("Weekday", bucket.label),
                        y: .value("Logs", bucket.count)
                    )
                    .foregroundStyle(
                        bucket.isPeak
                            ? LinearGradient(
                                colors: [.teal, .teal.opacity(0.5)],
                                startPoint: .top, endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [.white.opacity(0.45), .white.opacity(0.15)],
                                startPoint: .top, endPoint: .bottom
                            )
                    )
                }
            }
            .frame(height: 130)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20, tint: AppColors.glassTintAccent)
    }

    // MARK: - Top habits

    private var topHabitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(
                title: "Top Habits",
                subtitle: "Most logged in \(range.shortLabel)",
                icon: "trophy.fill"
            )

            VStack(spacing: 12) {
                ForEach(topHabits) { row in
                    topHabitRow(row)
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20, tint: AppColors.glassTintAccent)
    }

    private func topHabitRow(_ row: HabitRow) -> some View {
        let progress = topHabitsMax > 0 ? Double(row.count) / Double(topHabitsMax) : 0
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(row.color.opacity(0.30))
                    .frame(width: 34, height: 34)
                Image(systemName: row.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(row.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text("\(row.count)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.06))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [row.color, row.color.opacity(0.55)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * progress))
                    }
                }
                .frame(height: 6)
            }
        }
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(
                title: "12-Week Consistency",
                subtitle: "Every square is a day",
                icon: "square.grid.3x3.fill"
            )

            HeatmapView(completions: completions)

            HStack(spacing: 6) {
                Text("LESS")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.4))
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(HeatmapView.color(for: level))
                        .frame(width: 12, height: 12)
                }
                Text("MORE")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(18)
        .glassCard(cornerRadius: 20, tint: AppColors.glassTintAccent)
    }

    // MARK: - Feed header & empty state

    private var feedHeader: some View {
        HStack {
            Text("RECENT LOGS")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
        }
        .padding(.top, 6)
        .padding(.horizontal, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.4))
            Text("No completions yet")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("Log a habit on the Today tab and it will show up here.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Card header util

    private func cardHeader(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.20))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(AppColors.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
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

    private var longestStreak: Int {
        habits.map(\.streak).max() ?? 0
    }

    private var activeHabitCount: Int { habits.count }

    private var rangeStart: Date? {
        guard let days = range.days else { return nil }
        return Date().startOfDay.adding(days: -(days - 1))
    }

    private var rangedCompletions: [HabitCompletion] {
        guard let start = rangeStart else { return completions }
        return completions.filter { $0.date >= start }
    }

    private var activeDaysInRange: Int {
        let cal = Calendar.current
        return Set(rangedCompletions.map { cal.startOfDay(for: $0.date) }).count
    }

    private var dailyBuckets: [DailyBucket] {
        let cal = Calendar.current
        let counts = Dictionary(grouping: rangedCompletions) { cal.startOfDay(for: $0.date) }
            .mapValues(\.count)

        let days: [Date]
        if let start = rangeStart, let total = range.days {
            days = (0..<total).map { start.adding(days: $0) }
        } else if let earliest = completions.last?.date {
            let start = cal.startOfDay(for: earliest)
            let today = Date().startOfDay
            let count = max(1, (cal.dateComponents([.day], from: start, to: today).day ?? 0) + 1)
            days = (0..<count).map { start.adding(days: $0) }
        } else {
            days = [Date().startOfDay]
        }
        return days.map { DailyBucket(date: $0, count: counts[$0] ?? 0) }
    }

    private var averageInRange: Double {
        guard !dailyBuckets.isEmpty else { return 0 }
        let total = dailyBuckets.reduce(0) { $0 + $1.count }
        return Double(total) / Double(dailyBuckets.count)
    }

    private var weekdayBuckets: [WeekdayBucket] {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        var counts = Array(repeating: 0, count: 7)
        for c in rangedCompletions {
            let wd = cal.component(.weekday, from: c.date) - 1
            if wd >= 0 && wd < 7 { counts[wd] += 1 }
        }
        let peak = counts.max() ?? 0
        return (0..<7).map { i in
            WeekdayBucket(
                weekday: i,
                label: symbols[safe: i] ?? "?",
                count: counts[i],
                isPeak: peak > 0 && counts[i] == peak
            )
        }
    }

    private var peakWeekdaySubtitle: String {
        let cal = Calendar.current
        let symbols = cal.weekdaySymbols
        var counts = Array(repeating: 0, count: 7)
        for c in rangedCompletions {
            let wd = cal.component(.weekday, from: c.date) - 1
            if wd >= 0 && wd < 7 { counts[wd] += 1 }
        }
        guard let max = counts.max(), max > 0,
              let idx = counts.firstIndex(of: max) else {
            return "Log to discover your rhythm"
        }
        return "\(symbols[safe: idx] ?? "—") is your strongest day"
    }

    private var topHabits: [HabitRow] {
        let countByHabit = Dictionary(grouping: rangedCompletions, by: { $0.habit?.id })
            .mapValues(\.count)

        let rows = habits.compactMap { habit -> HabitRow? in
            let count = countByHabit[habit.id] ?? 0
            guard count > 0 else { return nil }
            return HabitRow(
                id: habit.id,
                title: habit.title,
                symbol: habit.symbol,
                color: habit.color,
                count: count
            )
        }
        return Array(rows.sorted { $0.count > $1.count }.prefix(5))
    }

    private var topHabitsMax: Int { topHabits.map(\.count).max() ?? 1 }

    private var xStrideDays: Int {
        switch range {
        case .week:    return 1
        case .month:   return 5
        case .quarter: return 14
        case .all:     return max(1, dailyBuckets.count / 6)
        }
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

// MARK: - Time range

private enum TimeRange: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "30D"
    case quarter = "90D"
    case all = "ALL"

    var id: String { rawValue }
    var label: String { rawValue }

    var shortLabel: String {
        switch self {
        case .week:    return "last 7 days"
        case .month:   return "last 30 days"
        case .quarter: return "last 90 days"
        case .all:     return "all time"
        }
    }

    var days: Int? {
        switch self {
        case .week:    return 7
        case .month:   return 30
        case .quarter: return 90
        case .all:     return nil
        }
    }
}

// MARK: - Bucket models

private struct DailyBucket: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}

private struct WeekdayBucket: Identifiable {
    let weekday: Int
    let label: String
    let count: Int
    let isPeak: Bool
    var id: Int { weekday }
}

private struct HabitRow: Identifiable {
    let id: UUID
    let title: String
    let symbol: String
    let color: Color
    let count: Int
}

// MARK: - Heatmap

private struct HeatmapView: View {
    let completions: [HabitCompletion]

    private let weeks = 12

    var body: some View {
        let cal = Calendar.current
        let today = Date().startOfDay
        let startOfThisWeek = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let startDate = cal.date(byAdding: .weekOfYear, value: -(weeks - 1), to: startOfThisWeek) ?? today
        let counts = bucketCompletions(start: startDate)

        HStack(alignment: .top, spacing: 4) {
            VStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(height: 14)
                }
            }
            .frame(width: 12)

            HStack(spacing: 4) {
                ForEach(0..<weeks, id: \.self) { weekIndex in
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let date = cal.date(byAdding: .day, value: weekIndex * 7 + dayIndex, to: startDate) ?? startDate
                            let key = date.startOfDay
                            let inFuture = key > today
                            let count = counts[key] ?? 0

                            RoundedRectangle(cornerRadius: 3)
                                .fill(inFuture ? Color.white.opacity(0.02) : HeatmapView.color(for: level(for: count)))
                                .overlay {
                                    if key == today {
                                        RoundedRectangle(cornerRadius: 3)
                                            .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.8)
                                    }
                                }
                                .frame(height: 14)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return (0..<7).map { symbols[(first + $0) % 7] }
    }

    private func bucketCompletions(start: Date) -> [Date: Int] {
        var dict: [Date: Int] = [:]
        for c in completions where c.date >= start {
            dict[c.date.startOfDay, default: 0] += 1
        }
        return dict
    }

    private func level(for count: Int) -> Int {
        switch count {
        case 0:     return 0
        case 1:     return 1
        case 2:     return 2
        case 3...4: return 3
        default:    return 4
        }
    }

    static func color(for level: Int) -> Color {
        switch level {
        case 0:  return Color.white.opacity(0.06)
        case 1:  return AppColors.primary.opacity(0.32)
        case 2:  return AppColors.primary.opacity(0.55)
        case 3:  return AppColors.primary.opacity(0.78)
        default: return AppColors.primary
        }
    }
}

// MARK: - Day group

struct DayGroup: Identifiable {
    let date: Date
    let completions: [HabitCompletion]
    var id: Date { date }
}

private struct DayGroupView: View {
    let group: DayGroup
    let onDelete: (HabitCompletion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(headerTitle.uppercased())
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
            .padding(.top, 14)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(group.completions.enumerated()), id: \.element.id) { index, completion in
                    CompletionRow(completion: completion, onDelete: { onDelete(completion) })
                    if index < group.completions.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.leading, 60)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .glassCard(cornerRadius: 16, tint: AppColors.glassTintAccent)
    }

    private var headerTitle: String {
        if group.date.isToday { return "Today" }
        if group.date.isYesterday { return "Yesterday" }
        return group.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

// MARK: - Safe array subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
