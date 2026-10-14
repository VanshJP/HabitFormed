import AppIntents
import Foundation
import SwiftData

/// A habit as Siri and Shortcuts see it: its name and glyph.
struct HabitEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static let defaultQuery = HabitEntityQuery()

    let id: UUID
    let title: String
    let symbol: String

    init(_ habit: Habit) {
        id = habit.id
        title = habit.title
        symbol = habit.symbol
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", image: .init(systemName: symbol))
    }
}

/// Finds habits by id, lists them in grid order, and matches a spoken name
/// loosely, so "piano" finds "Practice piano".
struct HabitEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        try await allHabits().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        try await allHabits()
    }

    func entities(matching string: String) async throws -> [HabitEntity] {
        try await allHabits().filter { $0.title.localizedStandardContains(string) }
    }

    @MainActor
    private func allHabits() throws -> [HabitEntity] {
        let context = Habit_FormedApp.sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor).map(HabitEntity.init)
    }
}
