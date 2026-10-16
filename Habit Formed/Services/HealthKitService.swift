import Foundation
import HealthKit
import SwiftData

// MARK: - Day Health Metrics

/// One day's Apple Health numbers for the daily report. Every value is
/// optional: nil means no permission or no samples, and the card skips it.
nonisolated struct DayHealthMetrics: Sendable, Hashable {
    var steps: Double?
    var activeKcal: Double?
    var restingKcal: Double?
    var eatenKcal: Double?
    var exerciseMinutes: Double?
    var sleepHours: Double?
    var mindfulMinutes: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    /// What the exercise minutes went on, by kind of workout. Empty on a day
    /// without a workout.
    var exerciseKinds: [ExerciseKind] = []
    /// The night's sleep, from falling asleep to waking (`mainSleep`).
    var sleepSpan: DateInterval?
    /// When each of the day's workouts ran.
    var workoutSpans: [DateInterval] = []

    static let empty = DayHealthMetrics()

    /// The night's sleep as one span: asleep samples less than an hour apart
    /// join, and the stretch with the most sleep wins, so a nap stays out.
    static func mainSleep(_ spans: [DateInterval]) -> DateInterval? {
        var stretches: [(span: DateInterval, asleep: TimeInterval)] = []
        for span in spans.sorted(by: { $0.start < $1.start }) {
            if let last = stretches.last, span.start.timeIntervalSince(last.span.end) < 3600 {
                let joined = DateInterval(start: last.span.start, end: max(last.span.end, span.end))
                stretches[stretches.count - 1] = (joined, last.asleep + span.duration)
            } else {
                stretches.append((span, span.duration))
            }
        }
        return stretches.max { $0.asleep < $1.asleep }?.span
    }

    /// Active plus resting energy. Nil only when Health has neither.
    var burnedKcal: Double? {
        guard activeKcal != nil || restingKcal != nil else { return nil }
        return (activeKcal ?? 0) + (restingKcal ?? 0)
    }

    /// Eaten minus burned: negative is a deficit.
    var netKcal: Double? {
        guard let eatenKcal, let burnedKcal else { return nil }
        return eatenKcal - burnedKcal
    }

    var hasMacros: Bool { protein != nil || carbs != nil || fat != nil }

    /// Each macro's share of the energy the three carry (4, 4 and 9 kcal a
    /// gram), summing to 1, or nil while none has any.
    var macroShares: (protein: Double, carbs: Double, fat: Double)? {
        let p = max(protein ?? 0, 0) * 4
        let c = max(carbs ?? 0, 0) * 4
        let f = max(fat ?? 0, 0) * 9
        let total = p + c + f
        guard total > 0, total.isFinite else { return nil }
        return (p / total, c / total, f / total)
    }
}

/// Exercise minutes spent on one kind of workout ("Strength", "Walk"), or
/// outside any named one ("Other").
nonisolated struct ExerciseKind: Sendable, Hashable {
    let name: String
    let minutes: Double
    var isOther = false

    /// The kinds longest first, at most `limit` of them: past it the shortest
    /// fold into "Other", which comes last. With a `total`, "Other" is what
    /// the named kinds leave of it, and kinds adding up past it (workouts
    /// that overlap) are scaled to fit; without one it is `other`. Empty when
    /// no named kind has a minute.
    static func split(_ named: [String: Double], other: Double, total: Double?, limit: Int = 3) -> [ExerciseKind] {
        var kinds = named.filter { $0.value >= 0.5 }
            .map { ExerciseKind(name: $0.key, minutes: $0.value) }
            .sorted { $0.minutes != $1.minutes ? $0.minutes > $1.minutes : $0.name < $1.name }
        guard !kinds.isEmpty else { return [] }
        let covered = kinds.reduce(0) { $0 + $1.minutes }
        var rest = other
        if let total {
            if covered > total, covered > 0 {
                kinds = kinds.map { ExerciseKind(name: $0.name, minutes: $0.minutes * total / covered) }
            }
            rest = max(total - covered, 0)
        }
        let room = rest >= 0.5 ? limit - 1 : limit
        if kinds.count > room {
            let keep = max(limit - 1, 1)
            rest += kinds.dropFirst(keep).reduce(0) { $0 + $1.minutes }
            kinds = Array(kinds.prefix(keep))
        }
        if rest >= 0.5 { kinds.append(ExerciseKind(name: "Other", minutes: rest, isOther: true)) }
        return kinds
    }
}

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

    /// Latest today-value per source (keyed by `HealthKitSource.rawValue`).
    /// Updated every sync; tiles read from here without extra queries.
    var liveValues: [String: Double] = [:]

    /// Latest week-to-date sum per source. Populated for any source that
    /// backs at least one weekly habit so weekly tiles can show progress
    /// without redoing the HealthKit query themselves.
    var liveWeeklyValues: [String: Double] = [:]

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

    /// Asks only for the types `sources` read, so a sleep habit's sheet lists
    /// Sleep alone. Types already answered are not asked again.
    func requestAuthorization(for sources: Set<HealthKitSource>) async throws {
        guard isAvailable else { throw HealthKitError.unavailable }
        let types = Set(sources.compactMap { sampleType(for: $0) as HKObjectType? })
        guard !types.isEmpty else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: types)
            hasRequestedAuthorization = true
        } catch {
            throw HealthKitError.authorizationFailed(error)
        }
    }

    /// The extra types a daily report reads: food energy and macros, and the
    /// resting burn that completes "calories out". Asked for when a report
    /// that shows them first opens, not at launch, so the Health sheet only
    /// appears for people who want calories on a card.
    private var reportReadTypes: Set<HKObjectType> {
        var set = readTypes
        let qtypes: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed, .basalEnergyBurned,
            .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal,
        ]
        for id in qtypes {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { set.insert(t) }
        }
        set.insert(HKObjectType.workoutType())
        return set
    }

    func requestReportAuthorization() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: [], read: reportReadTypes)
    }

    // MARK: - Day metrics (daily report)

    /// Every number a daily report can print for `day`. Missing data (no
    /// permission, no samples) comes back nil and the card leaves it out.
    func dayMetrics(for day: Date) async -> DayHealthMetrics {
        guard isAvailable else { return .empty }
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        // Sleep belongs to the night before the day it is reported on.
        let sleepStart = start.addingTimeInterval(-6 * 60 * 60)
        let sleepEnd = start.addingTimeInterval(18 * 60 * 60)

        func quantity(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit) async -> Double? {
            guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
            return await sumQuantity(type: type, unit: unit, start: start, end: end)
        }

        var metrics = DayHealthMetrics()
        metrics.steps = await quantity(.stepCount, .count())
        metrics.activeKcal = await quantity(.activeEnergyBurned, .kilocalorie())
        metrics.restingKcal = await quantity(.basalEnergyBurned, .kilocalorie())
        metrics.eatenKcal = await quantity(.dietaryEnergyConsumed, .kilocalorie())
        metrics.exerciseMinutes = await quantity(.appleExerciseTime, .minute())
        metrics.protein = await quantity(.dietaryProtein, .gram())
        metrics.carbs = await quantity(.dietaryCarbohydrates, .gram())
        metrics.fat = await quantity(.dietaryFatTotal, .gram())

        if let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
           let spans = await asleepSpans(type: type, start: sleepStart, end: sleepEnd) {
            let seconds = spans.reduce(0) { $0 + $1.duration }
            if seconds > 0 { metrics.sleepHours = seconds / 3600 }
            metrics.sleepSpan = DayHealthMetrics.mainSleep(spans)
        }
        if let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession),
           let seconds = await sumCategoryDuration(type: type, start: start, end: end),
           seconds > 0 {
            metrics.mindfulMinutes = seconds / 60
        }
        let dayWorkouts = await workouts(start: start, end: end) ?? []
        metrics.workoutSpans = dayWorkouts.map { DateInterval(start: $0.start, end: max($0.end, $0.start)) }
        metrics.exerciseKinds = await exerciseKinds(of: dayWorkouts, total: metrics.exerciseMinutes)
        // Without an Apple Watch Health counts no exercise minutes, so the
        // workouts' own lengths make the total.
        if metrics.exerciseMinutes == nil, !metrics.exerciseKinds.isEmpty {
            metrics.exerciseMinutes = metrics.exerciseKinds.reduce(0) { $0 + $1.minutes }
        }
        return metrics
    }

    /// The day's exercise minutes by kind of workout: what Health counted as
    /// exercise during each one, with the rest as "Other". Without exercise
    /// minutes, each workout's own length. Empty on a day without a workout.
    private func exerciseKinds(of workouts: [Workout], total: Double?) async -> [ExerciseKind] {
        guard !workouts.isEmpty else { return [] }
        let exercise = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)
        var named: [String: Double] = [:]
        var other = 0.0
        for workout in workouts {
            var minutes = workout.minutes
            if total != nil, let exercise {
                minutes = await sumQuantity(type: exercise, unit: .minute(), start: workout.start, end: workout.end) ?? 0
            }
            if let name = workout.name {
                named[name, default: 0] += minutes
            } else {
                other += minutes
            }
        }
        return ExerciseKind.split(named, other: other, total: total)
    }

    /// One workout as plain values, so it can leave HealthKit's callback.
    private nonisolated struct Workout: Sendable {
        let name: String?
        let start: Date
        let end: Date
        let minutes: Double
    }

    private func workouts(start: Date, end: Date) async -> [Workout]? {
        await withCheckedContinuation { cont in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let q = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard error == nil, let samples else { cont.resume(returning: nil); return }
                let workouts = samples.compactMap { $0 as? HKWorkout }.map {
                    Workout(name: Self.name(of: $0.workoutActivityType), start: $0.startDate, end: $0.endDate, minutes: $0.duration / 60)
                }
                cont.resume(returning: workouts)
            }
            store.execute(q)
        }
    }

    /// A short name for a kind of workout, or nil for one that counts as
    /// "Other". Kinds alike share a name, so two strength sessions are one.
    nonisolated private static func name(of type: HKWorkoutActivityType) -> String? {
        switch type {
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .walking: return "Walk"
        case .running: return "Run"
        case .cycling, .handCycling: return "Cycle"
        case .swimming: return "Swim"
        case .hiking: return "Hike"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .highIntensityIntervalTraining: return "HIIT"
        case .coreTraining: return "Core"
        case .mixedCardio, .crossTraining, .jumpRope: return "Cardio"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing, .stairs, .stepTraining: return "Stairs"
        case .flexibility, .preparationAndRecovery, .cooldown: return "Stretch"
        case .socialDance, .cardioDance: return "Dance"
        case .boxing, .kickboxing, .martialArts: return "Combat"
        case .climbing: return "Climb"
        case .tennis, .pickleball, .badminton, .squash, .racquetball, .tableTennis: return "Racket"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .golf: return "Golf"
        case .mindAndBody, .taiChi: return "Mind and body"
        case .downhillSkiing, .crossCountrySkiing, .snowboarding: return "Snow"
        default: return nil
        }
    }

    // MARK: - Readings

    /// `source`'s total from `start` to `end`: one day for a daily habit, the
    /// week so far for a weekly one. Nil when Health has no answer, as on a
    /// locked phone (Health stays sealed until it is unlocked).
    func reading(for source: HealthKitSource, from start: Date, to end: Date) async -> Double? {
        guard isAvailable else { return nil }
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
            let secs = await sumSleepAsleep(type: t, start: start, end: end)
            return secs.map { $0 / 3600.0 }
        case .standHours:
            guard let t = HKCategoryType.categoryType(forIdentifier: .appleStandHour) else { return nil }
            return await countStoodHours(type: t, start: start, end: end)
        }
    }

    // MARK: - Sync

    /// The day `liveValues` were read for and the week `liveWeeklyValues`
    /// were. A new one starts them empty, so a total read yesterday never
    /// stands in for today's.
    @ObservationIgnored private var liveDay: Date?
    @ObservationIgnored private var liveWeek: Date?
    /// Set once past logs have been checked this launch (`checkPastLogs`).
    @ObservationIgnored private var checkedPastLogs = false

    /// Reads each health habit's total for today (or the week so far), logs
    /// the ones at goal, and takes back a log the reading contradicts.
    @MainActor
    func syncHealthKitHabits(in context: ModelContext) async {
        guard isAvailable else { return }
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.sourceRaw != "none" })
        guard let tracked = try? context.fetch(descriptor) else { return }

        // One day for the whole pass: read for it, log on it.
        let now = Date()
        let day = now.startOfDay
        let week = Date.startOfWeek(for: day)
        if liveDay != day {
            liveDay = day
            liveValues = [:]
        }
        if liveWeek != week {
            liveWeek = week
            liveWeeklyValues = [:]
        }

        var dayTotals: [String: Double] = [:]
        var weekTotals: [String: Double] = [:]
        for source in Set(tracked.filter { $0.frequency != .weekly }.map(\.source)) {
            dayTotals[source.rawValue] = await reading(for: source, from: day, to: day.nextDayStart)
        }
        for source in Set(tracked.filter { $0.frequency == .weekly }.map(\.source)) {
            weekTotals[source.rawValue] = await reading(for: source, from: week, to: now)
        }
        // A pass that crossed midnight while it read leaves the new day's
        // values alone. Only a real change is written: every write redraws
        // each tile that reads these values.
        if liveDay == day {
            for (key, total) in dayTotals where liveValues[key] != total { liveValues[key] = total }
            for (key, total) in weekTotals where liveWeeklyValues[key] != total { liveWeeklyValues[key] = total }
        }

        // Fetched again, so a habit deleted while Health answered is not touched.
        guard let habits = try? context.fetch(descriptor) else { return }
        var changed = false
        for habit in habits {
            let weekly = habit.frequency == .weekly
            guard let total = (weekly ? weekTotals : dayTotals)[habit.source.rawValue] else { continue }
            let logs = weekly ? habit.completionsInWeek(of: day) : habit.completion(on: day).map { [$0] } ?? []
            if total >= habit.targetValue {
                guard logs.isEmpty else { continue }
                context.insert(HabitCompletion(date: day, value: total, habit: habit))
                changed = true
            } else {
                for log in logs where Self.contradicts(total, logged: log.value, goal: habit.targetValue) {
                    context.delete(log)
                    changed = true
                }
            }
        }
        if changed { try? context.save() }
        await checkPastLogs(before: day, in: context)
    }

    /// True when `total`, read for a log's own day (or week), shows the log
    /// was never read from it. Sync records the total it saw, at or over
    /// goal; a log by hand records the goal itself and is left alone. Totals
    /// only grow through a day, so one now under the logged total and under
    /// goal means the log carried another day's total.
    private static func contradicts(_ total: Double, logged: Double, goal: Double) -> Bool {
        logged != goal && total < logged && total < goal
    }

    /// Once a launch, checks the last 30 days' logs of daily health habits
    /// against their own day's total and takes back the ones it contradicts.
    /// Tried again on the next sync while Health reads nothing (a locked phone).
    private func checkPastLogs(before day: Date, in context: ModelContext) async {
        guard !checkedPastLogs else { return }
        checkedPastLogs = true
        let start = day.adding(days: -30)
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.sourceRaw != "none" && $0.frequencyRaw != "weekly" })
        // As values, so a habit deleted while Health answers is never touched.
        let candidates = ((try? context.fetch(descriptor)) ?? []).flatMap { habit in
            (habit.completions ?? [])
                .filter { $0.date >= start && $0.date < day && $0.value != habit.targetValue }
                .map { (id: $0.id, day: $0.date, logged: $0.value, source: habit.source, goal: habit.targetValue) }
        }
        var answered = candidates.isEmpty
        var stray: [UUID] = []
        for log in candidates {
            guard let total = await reading(for: log.source, from: log.day, to: log.day.nextDayStart) else { continue }
            answered = true
            if Self.contradicts(total, logged: log.logged, goal: log.goal) { stray.append(log.id) }
        }
        checkedPastLogs = answered
        guard !stray.isEmpty else { return }
        let ids = stray
        let strayLogs = FetchDescriptor<HabitCompletion>(predicate: #Predicate { ids.contains($0.id) })
        for log in (try? context.fetch(strayLogs)) ?? [] { context.delete(log) }
        try? context.save()
    }

    // MARK: - Live observers

    /// Subscribe to HealthKit change notifications for every source we care
    /// about. As soon as new samples land (e.g. iPhone records more steps),
    /// the observer fires and we re-run the sync, keeping tiles like the
    /// step challenge up-to-date in near real-time instead of waiting on
    /// the slow polling fallback.
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

        // The container is Sendable; the context is not, so resolve it back
        // on the main actor (views hand us the container's mainContext).
        let container = context.container
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
            defer { completionHandler() }
            guard error == nil, let self else { return }
            Task { @MainActor in
                await self.syncHealthKitHabits(in: container.mainContext)
            }
        }
        store.execute(query)
        activeObservers[key] = query

        // Background delivery keeps the observer firing while the app is
        // suspended, so a goal reached in the background is logged by the
        // next look. Hourly: immediate wakes the app on every Watch sync.
        store.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { _, _ in }
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
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard error == nil, let samples else { cont.resume(returning: nil); return }
                let total = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                cont.resume(returning: total)
            }
            store.execute(q)
        }
    }

    private func sumSleepAsleep(type: HKCategoryType, start: Date, end: Date) async -> Double? {
        await asleepSpans(type: type, start: start, end: end)?.reduce(0) { $0 + $1.duration }
    }

    /// Each asleep sample's span (core, deep, REM or unspecified), or nil
    /// when Health has no answer.
    private func asleepSpans(type: HKCategoryType, start: Date, end: Date) async -> [DateInterval]? {
        await withCheckedContinuation { cont in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard error == nil, let samples else { cont.resume(returning: nil); return }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]
                let spans = samples
                    .compactMap { $0 as? HKCategorySample }
                    .filter { asleepValues.contains($0.value) && $0.endDate > $0.startDate }
                    .map { DateInterval(start: $0.startDate, end: $0.endDate) }
                cont.resume(returning: spans)
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
