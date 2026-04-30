//
//  Habit_FormedApp.swift
//  Habit Formed
//
//  Created by Vansh Patel on 4/27/26.
//

import SwiftUI
import SwiftData

@main
struct Habit_FormedApp: App {
    // Shared services injected via .environment so views never recreate them.
    @State private var health = HealthKitService()
    @State private var notifications: NotificationService
    @State private var timer: TimerCenter
    @State private var dayTracker = DayTracker()

    init() {
        let n = NotificationService()
        _notifications = State(initialValue: n)
        _timer = State(initialValue: TimerCenter(notifications: n))
    }

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Habit.self,
            HabitCompletion.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("Failed to create ModelContainer: \(error)")
            // Last-resort in-memory store keeps the app launchable instead of
            // silently wiping the user's data on a migration failure.
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(AppColors.primary)
                .environment(health)
                .environment(notifications)
                .environment(timer)
                .environment(dayTracker)
        }
        .modelContainer(sharedModelContainer)
    }
}
