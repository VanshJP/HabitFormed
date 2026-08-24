import SwiftUI
import SwiftData

enum AppTab: Hashable { case today, history }

struct RootView: View {
    @Environment(TimerCenter.self) private var timerCenter
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: AppTab = .today
    @State private var showAddHabit = false
    @State private var timerSheetHabit: Habit?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.today) {
                NavigationStack {
                    ContentView(onAdd: { Haptics.light(); showAddHabit = true })
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar(.hidden, for: .navigationBar)
                }
            }


            Tab("History", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                NavigationStack {
                    HistoryView()
                }
            }
        }
        .overlay(alignment: .bottom) {
            if timerCenter.isActive {
                MiniTimerBanner {
                    if let habit = lookupActiveTimerHabit() {
                        Haptics.medium()
                        timerSheetHabit = habit
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: timerCenter.isActive)
            }
        }
        .sheet(isPresented: $showAddHabit) {
            AddHabitView()
        }
        .sheet(item: $timerSheetHabit) { habit in
            TimerView(habit: habit)
        }
        .onReceive(NotificationCenter.default.publisher(for: .habitOpenTimerFromNotification)) { note in
            guard let habitID = note.userInfo?["habitID"] as? UUID,
                  let habit = lookupActiveHabit(id: habitID) else { return }
            Haptics.medium()
            timerSheetHabit = habit
        }
        .tint(AppColors.primary)
        .preferredColorScheme(.dark)
    }

    private func lookupActiveHabit(id: UUID) -> Habit? {
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func lookupActiveTimerHabit() -> Habit? {
        guard let id = timerCenter.habitID else { return nil }
        return lookupActiveHabit(id: id)
    }
}

// MARK: - Mini Timer Banner

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
                            .fill(center.habitColor.opacity(0.30))
                            .frame(width: 34, height: 34)
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(center.habitColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 34, height: 34)
                        Image(systemName: center.isRunning ? "waveform" : (isFinished ? "checkmark" : "pause.fill"))
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(center.habitTitle)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(stateLabel(isFinished: isFinished))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()

                    Text(formatted(displaySeconds))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular.tint(center.habitColor), in: .capsule)
            }
        }
        .buttonStyle(.plain)
    }

    private func stateLabel(isFinished: Bool) -> String {
        if isFinished { return "TAP TO LOG" }
        if center.isRunning { return "RUNNING" }
        return "PAUSED"
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
