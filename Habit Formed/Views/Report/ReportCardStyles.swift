import SwiftUI

// MARK: - Helpers

private extension ReportContent {
    var accent: Color { Color(hex: accentHex) }

    func expanded(_ text: String, _ report: DailyReport) -> String {
        ReportText.expand(text, report: report, content: self)
    }
}

/// The card's headline in the poster weight.
private struct ReportTitle: View {
    let text: String
    var size: CGFloat = 28

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Seven bars, one per day, filled to that day's completion.
private struct ReportWeekBars: View {
    let week: [DaySummary]
    var height: CGFloat = 26

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(week) { day in
                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(day.isPerfect ? AppColors.success : AppColors.progressColor(for: day.fraction))
                            .frame(height: max(day.fraction > 0 ? 4 : 0, height * day.fraction))
                    }
                    .frame(width: 8, height: height)
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }
}

/// A small flame and the perfect-day run, for cards that mention it.
private struct ReportStreakLine: View {
    let report: DailyReport

    var body: some View {
        HStack(spacing: 6) {
            StreakFlameGlyph(heat: .of(streak: report.perfectStreak, doneToday: report.isPerfect))
                .frame(height: 16)
            Text(report.perfectStreak == 1 ? "1 perfect day" : "\(report.perfectStreak) perfect days in a row")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

// MARK: - Scoreboard

/// A progress ring and the verdict over the checklist. The everyday report.
struct ScoreboardCard: View {
    let report: DailyReport
    let content: ReportContent

    var body: some View {
        DarkCardFrame(content: content) {
            ReportHeader(report: report, accent: content.accent)
            ReportTitle(text: content.expanded(content.title, report))
            hero
            ReportItemList(report: report, content: content)
            if content.showCalories {
                ReportCalorieStrip(health: report.health, goal: content.calorieGoal, accent: content.accent)
            }
            if content.showActivity {
                ReportActivityChips(health: report.health)
            }
            ReportMessage(text: content.expanded(content.message, report), accent: content.accent)
            ReportFooter(text: content.expanded(content.footer, report))
        }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 18) {
            ProgressRing(
                fraction: report.fraction,
                lineWidth: 11,
                color: report.isPerfect ? AppColors.success : content.accent
            ) {
                VStack(spacing: 0) {
                    Text("\(report.done)/\(report.expected)")
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("done")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 14)
            }
            .frame(width: 118, height: 118)

            VStack(alignment: .leading, spacing: 8) {
                Text(report.verdict)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("\(report.percentText) of the day")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                if content.showPerfectStreak, report.perfectStreak > 0 {
                    ReportStreakLine(report: report)
                }
                ReportWeekBars(week: report.week, height: 22)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Fuel

/// Calories first: what went in, what went out, the net and the budget. Then
/// macros, activity and habits.
struct FuelCard: View {
    let report: DailyReport
    let content: ReportContent

    private var health: DayHealthMetrics { report.health }

    var body: some View {
        DarkCardFrame(content: content) {
            ReportHeader(report: report, accent: content.accent)
            ReportTitle(text: content.expanded(content.title, report))
            inAndOut
            netBanner
            if content.calorieGoal > 0, let eaten = health.eatenKcal {
                budget(eaten: eaten, goal: content.calorieGoal)
            }
            if health.hasMacros {
                macros
            }
            if content.showActivity {
                ReportActivityChips(health: health)
            }
            ReportItemList(report: report, content: content)
            ReportMessage(text: content.expanded(content.message, report), accent: content.accent)
            ReportFooter(text: content.expanded(content.footer, report))
        }
    }

    private var inAndOut: some View {
        HStack(alignment: .top, spacing: 12) {
            bigNumber(label: "Eaten", value: health.eatenKcal, icon: "fork.knife", caption: health.eatenKcal == nil ? "Not logged" : "kcal")
            bigNumber(
                label: "Burned",
                value: health.burnedKcal,
                icon: "flame.fill",
                caption: burnCaption
            )
        }
    }

    private var burnCaption: String {
        guard health.burnedKcal != nil else { return "No data" }
        let active = health.activeKcal.map { "\($0.safeRounded.formatted()) active" }
        let resting = health.restingKcal.map { "\($0.safeRounded.formatted()) resting" }
        return [active, resting].compactMap { $0 }.joined(separator: " + ")
    }

    private func bigNumber(label: String, value: Double?, icon: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(content.accent)
                Text(label)
                    .eyebrowStyle(Color.white.opacity(0.6))
            }
            Text(value.map { $0.safeRounded.formatted() } ?? "n/a")
                .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous)
                .fill(Color.white.opacity(0.07))
        }
    }

    @ViewBuilder
    private var netBanner: some View {
        if let net = health.netKcal {
            let deficit = net <= 0
            HStack(spacing: 8) {
                Image(systemName: deficit ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                    .font(.title3)
                Text("\(abs(net).safeRounded.formatted()) kcal \(deficit ? "deficit" : "surplus")")
                    .font(.headline.monospacedDigit())
                Spacer(minLength: 0)
                Text("Net \(ReportFormat.signedKcal(net))")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(deficit ? AppColors.success : AppColors.warning)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous)
                    .fill((deficit ? AppColors.success : AppColors.warning).opacity(0.14))
            }
        }
    }

    private func budget(eaten: Double, goal: Double) -> some View {
        let fraction = eaten / goal
        let left = goal - eaten
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(eaten.safeRounded.formatted()) of \(goal.safeRounded.formatted()) kcal budget")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                Spacer(minLength: 6)
                Text(left >= 0 ? "\(left.safeRounded.formatted()) left" : "\((-left).safeRounded.formatted()) over")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(left >= 0 ? AppColors.success : AppColors.warning)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(fraction <= 1 ? content.accent : AppColors.warning)
                        .frame(width: max(8, proxy.size.width * min(fraction, 1)))
                }
            }
            .frame(height: 8)
        }
    }

    private var macros: some View {
        HStack(spacing: 10) {
            macro("Protein", health.protein, AppColors.info)
            macro("Carbs", health.carbs, AppColors.warning)
            macro("Fat", health.fat, Color(red: 0.80, green: 0.42, blue: 0.52))
        }
    }

    private func macro(_ label: String, _ grams: Double?, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(ReportFormat.grams(grams))
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            HStack(spacing: 4) {
                Circle().fill(tint).frame(width: 6, height: 6)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous)
                .fill(Color.white.opacity(0.06))
        }
    }
}

// MARK: - Check-in

/// For an accountability partner: a plain count, then what got done and what
/// did not, then the promise.
struct CheckInCard: View {
    let report: DailyReport
    let content: ReportContent

    private var done: [DailyReport.Item] { report.items.filter(\.isDone) }
    private var pending: [DailyReport.Item] {
        report.items.filter { $0.status == .open || $0.status == .missed }
    }
    private var flexible: [DailyReport.Item] { report.items.filter { $0.status == .flexible } }

    var body: some View {
        DarkCardFrame(content: content) {
            ReportHeader(report: report, accent: content.accent)

            HStack(alignment: .firstTextBaseline) {
                ReportTitle(text: content.expanded(content.title, report))
                Spacer(minLength: 8)
                if content.showPerfectStreak, report.perfectStreak > 0 {
                    Text("Day \(report.perfectStreak)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppColors.inkOnLight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AppColors.solidWhite))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("\(report.done) of \(report.expected) done")
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(report.isPerfect ? AppColors.success : content.accent)
                            .frame(width: report.fraction > 0 ? max(8, proxy.size.width * report.fraction) : 0)
                    }
                }
                .frame(height: 8)
            }

            group(title: "Done", items: done, empty: "Nothing yet.")
            if content.showUnfinished, !pending.isEmpty {
                group(title: report.isToday ? "Still to do" : "Missed", items: pending, empty: nil)
            }
            if content.showUnfinished, !flexible.isEmpty {
                group(title: "This week", items: flexible, empty: nil)
            }

            if content.showCalories {
                ReportCalorieStrip(health: report.health, goal: content.calorieGoal, accent: content.accent)
            }
            if content.showActivity {
                ReportActivityChips(health: report.health)
            }
            ReportMessage(text: content.expanded(content.message, report), accent: content.accent)
            ReportFooter(text: content.expanded(content.footer, report))
        }
    }

    private func group(title: String, items: [DailyReport.Item], empty: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .eyebrowStyle(Color.white.opacity(0.55))
            if items.isEmpty, let empty {
                Text(empty)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
            ForEach(items.prefix(ReportCardView.maxItems)) { item in
                ReportItemRow(item: item, content: content)
                    .padding(.horizontal, 12)
                    .background {
                        RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    }
            }
        }
    }
}

// MARK: - Streak

/// The perfect-day run as a poster: the flame, the number, the week.
struct StreakCard: View {
    let report: DailyReport
    let content: ReportContent

    private var heat: StreakHeat { .of(streak: report.perfectStreak, doneToday: report.isPerfect) }

    var body: some View {
        DarkCardFrame(content: content) {
            ReportHeader(report: report, accent: content.accent)

            VStack(spacing: 6) {
                StreakFlameGlyph(heat: heat)
                    .frame(height: 104)
                    .padding(.top, 8)
                Text("\(report.perfectStreak)")
                    .font(.system(size: 92, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(
                        LinearGradient(
                            colors: report.perfectStreak > 0
                                ? AppColors.streakFlameGradient
                                : [Color.white.opacity(0.7), Color.white.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text(report.perfectStreak == 1 ? "perfect day" : "perfect days in a row")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.75))
                ReportTitle(text: content.expanded(content.title, report), size: 22)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)

            weekRow

            HStack(spacing: 10) {
                stat("Today", "\(report.done)/\(report.expected)")
                stat("Best run", "\(report.bestStreak)")
                stat("This week", "\(report.week.filter(\.isPerfect).count)/7")
            }

            if !report.items.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(report.items) { item in
                        HStack(spacing: 5) {
                            Image(systemName: item.isDone ? "checkmark" : "circle.dashed")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(item.isDone ? Color(hex: item.colorHex).glyphTone : .white.opacity(0.4))
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(item.isDone ? 0.9 : 0.55))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                }
            }

            ReportMessage(text: content.expanded(content.message, report), accent: content.accent)
            ReportFooter(text: content.expanded(content.footer, report))
        }
    }

    private var weekRow: some View {
        HStack(spacing: 0) {
            ForEach(report.week) { day in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(day.isPerfect ? AppColors.warning : Color.white.opacity(0.06))
                        Circle()
                            .strokeBorder(day.isPerfect ? Color.clear : Color.white.opacity(0.18), lineWidth: 1)
                        if day.isPerfect {
                            Image(systemName: "flame.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.inkOnLight)
                        } else if day.expected > 0 {
                            Text("\(day.done)")
                                .font(.caption2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .frame(width: 30, height: 30)
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .eyebrowStyle(Color.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous)
                .fill(Color.white.opacity(0.06))
        }
    }
}

// MARK: - Week grid

/// Every habit across the seven days ending on the report day: one row per
/// habit, one cell per day, the week's count at the end, and each day's
/// completion along the bottom.
struct WeekGridCard: View {
    let report: DailyReport
    let content: ReportContent

    private let cell: CGFloat = 18
    private let gap: CGFloat = 4
    private let countWidth: CGFloat = 30

    private var perfectDays: Int { report.week.filter(\.isPerfect).count }

    var body: some View {
        DarkCardFrame(content: content) {
            ReportHeader(report: report, accent: content.accent)
            ReportTitle(text: content.expanded(content.title, report))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(perfectDays)")
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                Text(perfectDays == 1 ? "perfect day this week" : "perfect days this week")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer(minLength: 0)
            }

            grid

            if content.showPerfectStreak, report.perfectStreak > 0 {
                ReportStreakLine(report: report)
            }
            if content.showActivity {
                ReportActivityChips(health: report.health)
            }
            ReportMessage(text: content.expanded(content.message, report), accent: content.accent)
            ReportFooter(text: content.expanded(content.footer, report))
        }
    }

    private var grid: some View {
        let rows = Array(report.allItems.prefix(12))

        return VStack(spacing: 10) {
            HStack(spacing: gap) {
                Spacer(minLength: 0)
                ForEach(report.week) { day in
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(day.date.isSameDay(as: report.date) ? 0.95 : 0.45))
                        .frame(width: cell)
                }
                Color.clear.frame(width: countWidth, height: 1)
            }

            ForEach(rows) { item in
                let tint = Color(hex: item.colorHex)
                HStack(spacing: gap) {
                    HStack(spacing: 6) {
                        Image(systemName: item.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tint.glyphTone)
                            .frame(width: 18)
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                    }
                    ForEach(Array(item.week.enumerated()), id: \.offset) { _, logged in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(logged ? tint.glyphTone : Color.white.opacity(0.08))
                            .frame(width: cell, height: cell)
                    }
                    Text("\(item.week.filter { $0 }.count)/7")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: countWidth, alignment: .trailing)
                }
            }

            if report.allItems.count > rows.count {
                Text("+\(report.allItems.count - rows.count) more")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)

            HStack(spacing: gap) {
                Text("Day done")
                    .eyebrowStyle(Color.white.opacity(0.5))
                Spacer(minLength: 0)
                ForEach(report.week) { day in
                    ProgressRing(
                        fraction: day.fraction,
                        lineWidth: 2.5,
                        color: day.isPerfect ? AppColors.success : AppColors.progressColor(for: day.fraction)
                    )
                    .frame(width: cell, height: cell)
                }
                Color.clear.frame(width: countWidth, height: 1)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous)
                .fill(Color.white.opacity(0.07))
        }
    }
}
