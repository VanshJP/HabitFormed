import SwiftUI
import SwiftData

/// Drag habits into the order Today shows them.
struct ArrangeHabitsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(habits) { habit in
                        HStack(spacing: RowLayout.spacing) {
                            RowGlyph(icon: habit.symbol, tint: habit.color)
                            Text(habit.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer(minLength: 8)
                            Text(habit.scheduleLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(AppColors.wellFill)
                    }
                    .onMove(perform: move)
                } footer: {
                    Text("Drag to reorder. Today follows this order.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background { AppBackground(style: .subtle) }
            .navigationTitle("Arrange habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = habits
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, habit) in ordered.enumerated() where habit.sortOrder != index {
            habit.sortOrder = index
        }
        try? modelContext.save()
        Haptics.selection()
    }
}
