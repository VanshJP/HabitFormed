import Foundation
import HealthKit
import SwiftData

enum HealthKitError: LocalizedError {
    case unavailable
    case authorizationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .unavailable:                return "HealthKit is not available on this device."
        case .authorizationFailed(let e): return "HealthKit authorization failed: \(e.localizedDescription)"
        }
    }
}

@Observable
final class HealthKitService {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var hasRequestedAuthorization: Bool = false
    var lastSyncDate: Date?

    /// Latest today-value per source (keyed by `HealthKitSource.rawValue`).
    /// Updated every sync; tiles read from here without extra queries.
    var liveValues: [String: Double] = [:]

    /// Long-running observer queries keyed by source. Kept alive for the
    /// app's lifetime so HealthKit can push updates as soon as new samples
    /// land (steps walked, exercise logged, etc.) instead of waiting for
    /// the polling fallback.
    @ObservationIgnored
    private var activeObservers: [String: HKObserverQuery] = [:]

    // MARK: - Authorization

    private var readTypes: Set<HKObjectType> {
        var set: Set<HKObjectType> = []
        let qtypes: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .appleExerciseTime,
            .distanceWalkingRunning, .flightsClimbed,
        ]
        for id in qtypes {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { set.insert(t) }
        }
        let ctypes: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis, .mindfulSession, .appleStandHour,
        ]
        for id in ctypes {
            if let t = HKCategoryType.categoryType(forIdentifier: id) { set.insert(t) }
        }
        return set
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            hasRequestedAuthorization = true
        } catch {
            throw HealthKitError.authorizationFailed(error)
        }
    }

    // MARK: - Today's value

    func todayValue(for source: HealthKitSource) async -> Double? {
        guard isAvailable, source != .none else { return nil }
        let (start, end) = todayBounds()

        switch source {
        case .none:
            return nil

        case .steps:
            guard let t = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
            return await sumQuantity(type: t, unit: .count(), start: start, end: end)

        case .activeCalories:
            guard let t = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return nil }
            return await sumQuantity(type: t, unit: .kilocalorie(), start: start, end: end)

        case .exerciseMinutes:
            guard let t = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return nil }
            return await sumQuantity(type: t, unit: .minute(), start: start, end: end)

        case .walkingDistance:
            guard let t = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return nil }
            let meters = await sumQuantity(type: t, unit: .meter(), start: start, end: end)
            return meters.map { $0 / 1000.0 }

        case .flightsClimbed:
            guard let t = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else { return nil }
            return await sumQuantity(type: t, unit: .count(), start: start, end: end)

        case .mindfulMinutes:
            guard let t = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return nil }
            let secs = await sumCategoryDuration(type: t, start: start, end: end)
            return secs.map { $0 / 60.0 }

        case .sleepHours:
            guard let t = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
            let from = end.addingTimeInterval(-24 * 60 * 60)
            let secs = await sumSleepAsleep(type: t, start: from, end: end)
            return secs.map { $0 / 3600.0 }

        case .standHours:
            guard let t = HKCategoryType.categoryType(forIdentifier: .appleStandHour) else { return nil }
            return await countStoodHours(type: t, start: start, end: end)
        }
    }

    // MARK: - Sync

    @MainActor
    func syncHealthKitHabits(in context: ModelContext) async {
        guard isAvailable else { return }
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.sourceRaw != "none" })
        guard let habits = try? context.fetch(descriptor) else { return }

        var fetchedSources = Set<String>()

        for habit in habits {
            let key = habit.source.rawValue
            if !fetchedSources.contains(key) {
                if let value = await todayValue(for: habit.source) {
                    liveValues[key] = value
                }
                fetchedSources.insert(key)
            }

            guard let value = liveValues[key] else { continue }
            guard value >= habit.targetValue else { continue }
            guard !habit.isCompletedToday else { continue }

            context.insert(HabitCompletion(date: Date(), value: value, habit: habit))
        }

        try? context.save()
        lastSyncDate = Date()
    }

    // MARK: - Live observers

    /// Subscribe to HealthKit change notifications for every source we care
    /// about. As soon as new samples land (e.g. iPhone records more steps),
    /// the observer fires and we re-run the sync — keeping tiles like the
    /// step challenge up-to-date in near real-time instead of waiting on
    /// the 15s polling fallback.
    @MainActor
    func startObservingHealthKitHabits(in context: ModelContext) {
        guard isAvailable else { return }
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.sourceRaw != "none" })
        guard let habits = try? context.fetch(descriptor) else { return }

        let sources = Set(habits.map(\.source))
        for source in sources {
            registerObserver(for: source, context: context)
        }
    }

    @MainActor
    private func registerObserver(for source: HealthKitSource, context: ModelContext) {
        let key = source.rawValue
        guard activeObservers[key] == nil else { return }
        guard let sampleType = sampleType(for: source) else { return }

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
            defer { completionHandler() }
            guard error == nil, let self else { return }
            Task { @MainActor in
                await self.syncHealthKitHabits(in: context)
            }
        }
        store.execute(query)
        activeObservers[key] = query

        // Background delivery means the observer keeps firing even when the
        // app is suspended, so the next foregrounding has fresh data ready.
        store.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { _, _ in }
    }

    private func sampleType(for source: HealthKitSource) -> HKSampleType? {
        switch source {
        case .none:            return nil
        case .steps:           return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case .activeCalories:  return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case .exerciseMinutes: return HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)
        case .walkingDistance: return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .flightsClimbed:  return HKQuantityType.quantityType(forIdentifier: .flightsClimbed)
        case .mindfulMinutes:  return HKCategoryType.categoryType(forIdentifier: .mindfulSession)
        case .sleepHours:      return HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        case .standHours:      return HKCategoryType.categoryType(forIdentifier: .appleStandHour)
        }
    }

    // MARK: - Query helpers

    private func todayBounds() -> (Date, Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        return (start, end)
    }

    private func sumQuantity(type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async -> Double? {
        await withCheckedContinuation { cont in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(q)
        }
    }

    private func sumCategoryDuration(type: HKCategoryType, start: Date, end: Date) async -> Double? {
        await withCheckedContinuation { cont in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let total = (samples ?? []).reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                cont.resume(returning: total)
            }
            store.execute(q)
        }
    }

    private func sumSleepAsleep(type: HKCategoryType, start: Date, end: Date) async -> Double? {
        await withCheckedContinuation { cont in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]
                let total = (samples ?? [])
                    .compactMap { $0 as? HKCategorySample }
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                cont.resume(returning: total)
            }
            store.execute(q)
        }
    }

    private func countStoodHours(type: HKCategoryType, start: Date, end: Date) async -> Double? {
        await withCheckedContinuation { cont in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard error == nil, let samples else { cont.resume(returning: nil); return }
                let count = samples
                    .compactMap { $0 as? HKCategorySample }
                    .filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }
                    .count
                cont.resume(returning: Double(count))
            }
            store.execute(q)
        }
    }
}
