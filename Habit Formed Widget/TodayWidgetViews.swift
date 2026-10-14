import AppIntents
import SwiftUI
import WidgetKit

/// The widget's colours. The extension cannot see the app's `AppColors`, so
/// these repeat the few tokens it needs.
enum WidgetPalette {
    static let canvasTop = Color(hex: "#13204A")
    static let canvasBottom = Color(hex: "#080B1A")
    static let brand = Color(hex: "#2BA8A8")
    static let success = Color(hex: "#38CC80")
    static let warning = Color(hex: "#F5A93C")
    static let flame = Color(hex: "#FF8A2E")
    static let track = Color.white.opacity(0.12)
    static let secondary = Color.white.opacity(0.6)

    static var background: LinearGradient {
        LinearGradient(colors: [canvasTop, canvasBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Green when perfect, teal past halfway, amber before that.
    static func progress(done: Int, expected: Int) -> Color {
        guard expected > 0 else { return track }
        if done >= expected { return success }
        return Double(done) / Double(expected) >= 0.5 ? brand : warning
    }

    /// A habit's colour lifted toward white, so a glyph reads on the navy.
    static func glyph(_ hex: String) -> Color {
        Color(hex: hex).mix(with: .white, by: 0.35)
    }
}

/// Picks the layout for the widget's size.
struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        Group {
            if let page = entry.page {
                switch family {
                case .systemMedium:
                    MediumTodayView(page: page)
                default:
                    // Too small for buttons, so the whole widget is the way
                    // to today's report.
                    SmallTodayView(page: page)
                        .widgetURL(WidgetLink.report)
                }
            } else {
                Text("Open Habit Formed to start today.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WidgetPalette.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { WidgetPalette.background }
    }
}

// MARK: - Small

/// The day's ring, how many are left, and the perfect-day streak.
struct SmallTodayView: View {
    let page: WidgetSnapshot.Page

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(page.day.formatted(.dateTime.weekday(.abbreviated).day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetPalette.secondary)
                Spacer()
                if page.perfectStreak > 0 {
                    StreakBadge(count: page.perfectStreak)
                }
            }

            ZStack {
                DayRing(done: page.done, expected: page.expected, lineWidth: 8)
                Text("\(page.done)/\(page.expected)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: 78, maxHeight: 78)

            Text(remainingText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(page.isPerfect ? WidgetPalette.success : .white)
        }
    }

    private var remainingText: String {
        if page.expected == 0 { return "Nothing due" }
        if page.isPerfect { return "All done" }
        return "\(page.remaining) to go"
    }
}

// MARK: - Medium

/// The count and the week on the left; up to three habits on the right, the
/// open ones with a button that logs them without opening the app.
struct MediumTodayView: View {
    let page: WidgetSnapshot.Page

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(page.day.formatted(.dateTime.weekday(.abbreviated).day()))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetPalette.secondary)
                    if page.perfectStreak > 0 {
                        StreakBadge(count: page.perfectStreak)
                    }
                }
                Text("\(page.done) of \(page.expected)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.top, 4)
                Text(page.isPerfect ? "All done" : "done today")
                    .font(.caption)
                    .foregroundStyle(page.isPerfect ? WidgetPalette.success : WidgetPalette.secondary)
                Spacer(minLength: 0)
                WeekDots(week: page.week)
            }
            .frame(maxWidth: 118, maxHeight: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                let rows = Array(page.items.prefix(3))
                if rows.isEmpty {
                    Text("Nothing due today")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(WidgetPalette.secondary)
                } else {
                    ForEach(rows) { item in
                        HabitRow(item: item, day: page.day)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// One habit: glyph, name, and a log button or a check.
private struct HabitRow: View {
    let item: WidgetSnapshot.Item
    let day: Date

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WidgetPalette.glyph(item.colorHex))
                .frame(width: 20)
            Text(item.title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            mark
        }
        .frame(minHeight: 34)
        .opacity(item.isDone ? 0.55 : 1)
    }

    @ViewBuilder
    private var mark: some View {
        if item.isDone {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(WidgetPalette.success)
                .accessibilityLabel("Logged")
        } else if item.canLog {
            Button(intent: LogHabitIntent(habitID: item.id, day: day)) {
                Circle()
                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log \(item.title)")
        } else {
            Image(systemName: "heart.fill")
                .font(.caption)
                .foregroundStyle(WidgetPalette.secondary)
                .accessibilityLabel("Logs from Apple Health")
        }
    }
}

// MARK: - Pieces

/// The day's share logged, as a ring that closes green on a perfect day.
private struct DayRing: View {
    let done: Int
    let expected: Int
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(WidgetPalette.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: expected == 0 ? 0 : min(Double(done) / Double(expected), 1))
                .stroke(WidgetPalette.progress(done: done, expected: expected), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(done > 0 ? 1 : 0)
        }
        .padding(lineWidth / 2)
    }
}

/// Seven dots, oldest first: green for a perfect day, the progress colour for
/// a partial one, faint for nothing logged. The last dot is the widget's day.
private struct WeekDots: View {
    let week: [WidgetSnapshot.Day]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                let isLast = index == week.count - 1
                Circle()
                    .fill(fill(for: day, isLast: isLast))
                    .overlay {
                        if isLast && !day.isPerfect {
                            Circle().strokeBorder(WidgetPalette.brand, lineWidth: 2)
                        }
                    }
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(week.filter(\.isPerfect).count) perfect days this week")
    }

    private func fill(for day: WidgetSnapshot.Day, isLast: Bool) -> Color {
        if day.expected == 0 { return Color.white.opacity(0.06) }
        if day.done == 0 { return isLast ? .clear : WidgetPalette.track }
        return WidgetPalette.progress(done: day.done, expected: day.expected)
    }
}

/// The perfect-day streak: a flame and the count.
private struct StreakBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .foregroundStyle(WidgetPalette.flame)
            Text("\(count)")
                .monospacedDigit()
        }
        .font(.caption.weight(.bold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) perfect days in a row")
    }
}
