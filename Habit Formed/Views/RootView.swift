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
            NavigationStack {
                ContentView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tag(AppTab.today)
            .toolbar(.hidden, for: .tabBar)

            NavigationStack {
                HistoryView()
            }
            .tag(AppTab.history)
            .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if timerCenter.isActive {
                    MiniTimerBanner {
                        if let habit = lookupActiveHabit() {
                            Haptics.medium()
                            timerSheetHabit = habit
                        }
                    }
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                BottomBar(selectedTab: $selectedTab) {
                    Haptics.medium()
                    showAddHabit = true
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: timerCenter.isActive)
        }
        .sheet(isPresented: $showAddHabit) {
            AddHabitView()
        }
        .sheet(item: $timerSheetHabit) { habit in
            TimerView(habit: habit)
        }
        .tint(AppColors.primary)
        .preferredColorScheme(.dark)
    }

    private func lookupActiveHabit() -> Habit? {
        guard let id = timerCenter.habitID else { return nil }
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
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
                .background {
                    Capsule().fill(.ultraThinMaterial)
                }
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(
                            colors: [center.habitColor.opacity(0.5), .white.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
                )
                .clipShape(Capsule())
                .shadow(color: center.habitColor.opacity(0.25), radius: 10, y: 3)
            }
        }
        .buttonStyle(.plain)
    }

    private func stateLabel(isFinished: Bool) -> String {
        if isFinished { return "DONE — TAP TO LOG" }
        if center.isRunning { return "RUNNING" }
        return "PAUSED"
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Bottom Bar

private struct BottomBar: View {
    @Binding var selectedTab: AppTab
    let onAdd: () -> Void

    @Namespace private var tabNamespace
    @State private var pillHeight: CGFloat = 64

    private let tabs: [(AppTab, String, String)] = [
        (.today,   "house.fill",              "Home"),
        (.history, "clock.arrow.circlepath",  "History"),
    ]

    private var slideAnimation: Animation {
        .spring(response: 0.45, dampingFraction: 0.78)
    }

    var body: some View {
        if #available(iOS 26, *) {
            glassBar
        } else {
            legacyBar
        }
    }

    // MARK: - iOS 26+ Liquid Glass

    @available(iOS 26, *)
    private var glassBar: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(tabs, id: \.0) { tab, icon, label in
                        glassTabButton(tab, icon: icon, label: label)
                    }
                }
                .padding(6)
                .glassEffect(.regular.interactive(), in: .capsule)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: PillHeightKey.self, value: geo.size.height)
                    }
                )
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            let threshold: CGFloat = 40
                            guard let idx = tabs.firstIndex(where: { $0.0 == selectedTab }) else { return }
                            if value.translation.width < -threshold, idx < tabs.count - 1 {
                                Haptics.selection()
                                withAnimation(slideAnimation) { selectedTab = tabs[idx + 1].0 }
                            } else if value.translation.width > threshold, idx > 0 {
                                Haptics.selection()
                                withAnimation(slideAnimation) { selectedTab = tabs[idx - 1].0 }
                            }
                        }
                )

                Spacer(minLength: 0)

                Button(action: { Haptics.medium(); onAdd() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: pillHeight, height: pillHeight)
                }
                .foregroundStyle(.white)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Add habit")
            }
            .onPreferenceChange(PillHeightKey.self) { newHeight in
                if newHeight > 0 { pillHeight = newHeight }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
    }

    @available(iOS 26, *)
    private func glassTabButton(_ tab: AppTab, icon: String, label: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            Haptics.selection()
            withAnimation(slideAnimation) { selectedTab = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .symbolVariant(isSelected ? .fill : .none)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.white.opacity(0.14))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.45),
                                            .white.opacity(0.08),
                                            .white.opacity(0.02),
                                            .white.opacity(0.18)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.6
                                )
                        )
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                        .matchedGeometryEffect(id: "selectedTab", in: tabNamespace)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }

    // MARK: - Pre-iOS 26 fallback

    private var legacyBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 0) {
                ForEach(tabs, id: \.0) { tab, icon, label in
                    legacyTabButton(tab, icon: icon, label: label)
                }
            }
            .padding(4)
            .background(Capsule().fill(.ultraThinMaterial))

            Spacer()

            Button(action: { Haptics.medium(); onAdd() }) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.opacity(0.75)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 48, height: 48)
                        .shadow(color: AppColors.primary.opacity(0.45), radius: 10, y: 3)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add habit")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func legacyTabButton(_ tab: AppTab, icon: String, label: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { selectedTab = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .symbolVariant(isSelected ? .fill : .none)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.45))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule().fill(.white.opacity(0.15))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PillHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    let notifications = NotificationService()
    return RootView()
        .modelContainer(for: [Habit.self, HabitCompletion.self], inMemory: true)
        .environment(HealthKitService())
        .environment(notifications)
        .environment(TimerCenter(notifications: notifications))
}
