import SwiftUI
import SwiftData

enum AppTab: Hashable { case today, history }

/// What the shell presents over both tabs: the add flow, a timer opened from
/// a notification or the mini banner, and the daily report.
enum RootSheet: Identifiable {
    case addHabit
    case timer(Habit)
    case report(Date)

    var id: String {
        switch self {
        case .addHabit: return "add"
        case .timer(let habit): return "timer-\(habit.id.uuidString)"
        case .report(let date): return "report-\(date.timeIntervalSince1970)"
        }
    }
}

struct RootView: View {
    @Environment(TimerCenter.self) private var timerCenter
    @Environment(NotificationService.self) private var notifications
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppPreferences.appCanvas) private var canvasRaw = AppCanvas.classic.rawValue
    @AppStorage(AppPreferences.glassAppearance) private var glassRaw = GlassAppearance.light.rawValue
    @AppStorage(AppPreferences.reportReminderEnabled) private var reportReminderOn = false
    @AppStorage(AppPreferences.reportReminderHour) private var reportReminderHour = 21
    @AppStorage(AppPreferences.reportReminderMinute) private var reportReminderMinute = 0

    @State private var selectedTab: AppTab = .today
    @State private var sheet: RootSheet?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "square.grid.2x2.fill", value: AppTab.today) {
                // The canvas is painted inside each stack: SwiftUI hosts
                // navigation content in an opaque view, so a background behind
                // the TabView would never show.
                NavigationStack {
                    ContentView(
                        onAdd: { Haptics.light(); sheet = .addHabit },
                        onShareReport: { date in openReport(for: date) }
                    )
                    .background { AppBackground() }
                    .toolbar(.hidden, for: .navigationBar)
                }
            }

            Tab("History", systemImage: "calendar", value: AppTab.history) {
                NavigationStack {
                    HistoryView(onShareReport: { date in openReport(for: date) })
                        .background { AppBackground() }
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
        }
        .tint(.white)
        .overlay(alignment: .bottom) {
            if timerCenter.isActive {
                MiniTimerBanner {
                    if let habit = lookupActiveTimerHabit() {
                        Haptics.medium()
                        sheet = .timer(habit)
                    }
                }
                .padding(.horizontal, AppLayout.pageHorizontal)
                .padding(.bottom, 90)
                .readableColumn()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .motion(AppMotion.settle, value: timerCenter.isActive)
        .sheet(item: $sheet) { item in
            switch item {
            case .addHabit:
                AddHabitView()
            case .timer(let habit):
                TimerView(habit: habit)
            case .report(let date):
                DailyReportSheet(day: date)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .habitOpenTimerFromNotification)) { note in
            guard let habitID = note.userInfo?["habitID"] as? UUID,
                  let habit = lookupHabit(id: habitID) else { return }
            Haptics.medium()
            sheet = .timer(habit)
        }
        .onReceive(NotificationCenter.default.publisher(for: .habitOpenReportFromNotification)) { _ in
            openReport(for: Date())
        }
        .onOpenURL { url in
            guard url.scheme == WidgetLink.scheme else { return }
            if url.host() == WidgetLink.reportHost {
                openReport(for: Date())
            }
        }
        .task {
            // Re-anchors the repeating report nudge after a reinstall or a
            // permission change made in iOS Settings.
            if reportReminderOn {
                await notifications.syncReportReminder(
                    enabled: true,
                    hour: reportReminderHour,
                    minute: reportReminderMinute
                )
            }
        }
        .environment(\.glassAppearance, GlassAppearance(rawValue: glassRaw) ?? .light)
        .environment(\.appCanvas, AppCanvas(rawValue: canvasRaw) ?? .classic)
        .preferredColorScheme(.dark)
    }

    private func openReport(for date: Date) {
        Haptics.medium()
        sheet = .report(date.startOfDay)
    }

    private func lookupHabit(id: UUID) -> Habit? {
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func lookupActiveTimerHabit() -> Habit? {
        guard let id = timerCenter.habitID else { return nil }
        return lookupHabit(id: id)
    }
}

// MARK: - Mini Timer Banner

/// The running timer, floating over every tab: its ring, name and time. Tap to
/// open the full timer.
private struct MiniTimerBanner: View {
    @Environment(TimerCenter.self) private var center
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            TimelineView(.animation) { context in
                let interval = center.remainingInterval(at: context.date)
                let progress = center.progress(at: context.date)
                let displaySeconds = max(0, Int(interval.rounded(.up)))
                let isFinished = center.endDate != nil && interval <= 0

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(AppColors.meterTrack, lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(center.habitColor.glyphTone, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: center.isRunning ? "waveform" : (isFinished ? "checkmark" : "pause.fill"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(center.habitTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(stateLabel(isFinished: isFinished))
                            .eyebrowStyle()
                    }

                    Spacer()

                    Text(formatted(displaySeconds))
                        .font(.statValue)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: AppLayout.minHitTarget)
                .glassEffect(.regular.tint(AppColors.featuredTint(center.habitColor)).interactive(), in: .capsule)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(center.habitTitle) timer")
        .accessibilityHint("Opens the timer")
    }

    private func stateLabel(isFinished: Bool) -> String {
        if isFinished { return "Tap to log" }
        if center.isRunning { return "Running" }
        return "Paused"
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    let notifications = NotificationService()
    return RootView()
        .modelContainer(for: [Habit.self, HabitCompletion.self], inMemory: true)
        .environment(HealthKitService())
        .environment(notifications)
        .environment(TimerCenter(notifications: notifications))
        .environment(DayTracker())
}
