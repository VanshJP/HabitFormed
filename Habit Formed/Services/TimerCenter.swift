import ActivityKit
import Foundation
import SwiftData
import SwiftUI

/// App-wide persistent timer. Survives navigation, scene backgrounding,
/// and even cold launches because the running snapshot is mirrored into
/// `UserDefaults`. The countdown is derived from a fixed `endDate` rather
/// than a tick counter, so the displayed time stays accurate even if the
/// foreground tick stalls (e.g. the user backgrounds the app for 30s).
@Observable
@MainActor
final class TimerCenter {

    // MARK: - Persisted snapshot

    private struct Snapshot: Codable {
        let habitID: UUID
        let habitTitle: String
        let habitColorHex: String
        let habitSymbol: String
        let totalSeconds: Int
        let endDate: Date?                  // populated only while running
        let pausedRemaining: TimeInterval?  // populated only while paused
    }

    private static let snapshotKey = "timerCenter.snapshot.v1"

    // MARK: - Public state

    private(set) var habitID: UUID?
    private(set) var habitTitle: String = ""
    private(set) var habitColorHex: String = "#0D8488"
    private(set) var habitSymbol: String = "timer"
    private(set) var totalSeconds: Int = 0
    private(set) var endDate: Date?
    private(set) var pausedRemaining: TimeInterval?

    // MARK: - Dependencies

    private let notifications: NotificationService
    private var currentActivity: Activity<HabitTimerAttributes>?

    init(notifications: NotificationService) {
        self.notifications = notifications
        restore()
        reconnectLiveActivity()
        observeIntentToggles()
    }

    // MARK: - Computed

    var isActive: Bool { habitID != nil }
    var isRunning: Bool { endDate != nil }
    var isPaused: Bool { habitID != nil && endDate == nil }
    var habitColor: Color { Color(hex: habitColorHex) }

    var remainingSeconds: Int {
        // Ceil so the displayed time never shows 0:00 while there's still
        // sub-second time remaining — it transitions cleanly from 0:01 to
        // 0:00 only on the actual hit.
        Int(remainingInterval(at: Date()).rounded(.up))
    }

    var progress: Double { progress(at: Date()) }

    var hasFinished: Bool {
        isActive && endDate != nil && remainingInterval(at: Date()) <= 0
    }

    /// Continuous time-remaining at an arbitrary instant. Drives the
    /// `TimelineView` countdown ring so the visual is jitter-free.
    func remainingInterval(at date: Date) -> TimeInterval {
        if let endDate {
            return max(0, endDate.timeIntervalSince(date))
        }
        return pausedRemaining ?? TimeInterval(totalSeconds)
    }

    func progress(at date: Date) -> Double {
        guard totalSeconds > 0 else { return 0 }
        let total = TimeInterval(totalSeconds)
        return min(1, max(0, (total - remainingInterval(at: date)) / total))
    }

    // MARK: - Controls

    func start(habit: Habit) {
        let seconds = max(habit.timerDurationSeconds, 0)
        guard seconds > 0 else { return }
        configure(from: habit, totalSeconds: seconds)
        let end = Date().addingTimeInterval(TimeInterval(seconds))
        endDate = end
        pausedRemaining = nil
        notifications.scheduleTimerCompletion(habitID: habit.id, habitTitle: habit.title, fireAt: end)
        save()
        startLiveActivity(habit: habit, endDate: end)
    }

    /// Resume a partially-completed session that was previously paused or
    /// is currently running on a different sheet — e.g. the user opens
    /// `TimerView` for a habit whose timer is already mid-flight.
    func resume(habit: Habit) {
        // If we have a snapshot for this habit, just refresh metadata.
        if habitID == habit.id {
            habitTitle = habit.title
            habitColorHex = habit.colorHex
            habitSymbol = habit.symbol
            if let pausedRemaining {
                let end = Date().addingTimeInterval(pausedRemaining)
                endDate = end
                self.pausedRemaining = nil
                notifications.scheduleTimerCompletion(habitID: habit.id, habitTitle: habit.title, fireAt: end)
                save()
                updateLiveActivity()
            }
            return
        }
        // Otherwise treat as a fresh start.
        start(habit: habit)
    }

    func pause() {
        guard let endDate else { return }
        // Capture the precise remaining interval (no rounding) so the
        // ring doesn't snap forward/back when we toggle pause/resume.
        pausedRemaining = max(0, endDate.timeIntervalSinceNow)
        self.endDate = nil
        if let habitID {
            notifications.cancelTimerNotification(habitID: habitID)
        }
        save()
        updateLiveActivity()
    }

    /// Pause-or-resume from the active habit's cached metadata. Used by
    /// the Live Activity tap-to-toggle button via `TimerControlIntent`,
    /// which has no access to the SwiftData `Habit` object.
    func togglePause() {
        guard isActive, let habitID else { return }
        if isRunning {
            pause()
        } else if let pausedRemaining {
            let end = Date().addingTimeInterval(pausedRemaining)
            endDate = end
            self.pausedRemaining = nil
            notifications.scheduleTimerCompletion(habitID: habitID, habitTitle: habitTitle, fireAt: end)
            save()
            updateLiveActivity()
        }
    }

    /// Reset to the original duration but stay paused, so the user can
    /// restart manually.
    func reset() {
        guard isActive else { return }
        endDate = nil
        pausedRemaining = TimeInterval(totalSeconds)
        if let habitID {
            notifications.cancelTimerNotification(habitID: habitID)
        }
        save()
        updateLiveActivity()
    }

    /// Tear down state and any pending notification.
    func stop() {
        endLiveActivity(finished: false)
        tearDown()
    }

    /// Logs a `HabitCompletion` for the active timer (if not already
    /// logged today) and tears the timer down.
    func finish(in context: ModelContext, habit: Habit) {
        if !habit.isCompletedToday {
            let completion = HabitCompletion(date: Date(), value: habit.targetValue, habit: habit)
            context.insert(completion)
            try? context.save()
        }
        endLiveActivity(finished: true)
        tearDown()
    }

    // MARK: - Helpers

    private func configure(from habit: Habit, totalSeconds: Int) {
        habitID = habit.id
        habitTitle = habit.title
        habitColorHex = habit.colorHex
        habitSymbol = habit.symbol
        self.totalSeconds = totalSeconds
    }

    private func tearDown() {
        if let habitID {
            notifications.cancelTimerNotification(habitID: habitID)
        }
        habitID = nil
        habitTitle = ""
        habitColorHex = "#0D8488"
        habitSymbol = "timer"
        totalSeconds = 0
        endDate = nil
        pausedRemaining = nil
        UserDefaults.standard.removeObject(forKey: Self.snapshotKey)
    }

    // MARK: - Live Activity

    private func startLiveActivity(habit: Habit, endDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities are disabled in Settings")
            return
        }

        if let currentActivity {
            Task { await currentActivity.end(nil, dismissalPolicy: .immediate) }
            self.currentActivity = nil
        }

        let attributes = HabitTimerAttributes(
            habitID: habit.id.uuidString,
            habitTitle: habit.title,
            habitSymbol: habit.symbol,
            habitColorHex: habit.colorHex,
            totalSeconds: habit.timerDurationSeconds
        )
        let state = HabitTimerAttributes.ContentState(
            endDate: endDate,
            pausedRemaining: nil,
            isFinished: false
        )
        let content = ActivityContent(state: state, staleDate: endDate.addingTimeInterval(60))

        do {
            currentActivity = try Activity.request(attributes: attributes, content: content)
            print("✅ Live Activity started: \(currentActivity?.id ?? "nil")")
        } catch {
            print("⚠️ Live Activity request failed: \(error)")
        }
    }

    private func updateLiveActivity() {
        guard let currentActivity else { return }
        let state = HabitTimerAttributes.ContentState(
            endDate: endDate,
            pausedRemaining: pausedRemaining,
            isFinished: false
        )
        let content = ActivityContent(state: state, staleDate: endDate?.addingTimeInterval(60))
        Task { await currentActivity.update(content) }
    }

    private func endLiveActivity(finished: Bool) {
        guard let currentActivity else { return }
        let state = HabitTimerAttributes.ContentState(
            endDate: nil,
            pausedRemaining: nil,
            isFinished: finished
        )
        let content = ActivityContent(state: state, staleDate: nil)
        let policy: ActivityUIDismissalPolicy = finished ? .default : .immediate
        Task { await currentActivity.end(content, dismissalPolicy: policy) }
        self.currentActivity = nil
    }

    private func reconnectLiveActivity() {
        guard let habitID else { return }
        let idString = habitID.uuidString
        currentActivity = Activity<HabitTimerAttributes>.activities.first {
            $0.attributes.habitID == idString
        }
    }

    /// `TimerControlIntent.perform()` posts this notification on the
    /// host-app process so the Live Activity's pause/resume button can
    /// route through the same `togglePause()` path the in-app controls
    /// use.
    private func observeIntentToggles() {
        NotificationCenter.default.addObserver(
            forName: .habitTimerToggleFromActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePause() }
        }
    }

    // MARK: - Persistence

    private func save() {
        guard let habitID else { return }
        let snap = Snapshot(
            habitID: habitID,
            habitTitle: habitTitle,
            habitColorHex: habitColorHex,
            habitSymbol: habitSymbol,
            totalSeconds: totalSeconds,
            endDate: endDate,
            pausedRemaining: pausedRemaining
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
        }
    }

    private func restore() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.snapshotKey),
            let snap = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }

        habitID = snap.habitID
        habitTitle = snap.habitTitle
        habitColorHex = snap.habitColorHex
        habitSymbol = snap.habitSymbol
        totalSeconds = snap.totalSeconds
        endDate = snap.endDate
        pausedRemaining = snap.pausedRemaining

        // If the timer should have completed while the app was suspended,
        // clear it. The local notification will already have fired.
        if let endDate, endDate <= Date() {
            stop()
        }
    }
}
