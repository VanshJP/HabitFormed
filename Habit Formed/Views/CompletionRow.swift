import SwiftUI

/// One log in History's timeline: the habit's glyph and name, its note, and
/// the time it was logged. Long-press to remove it.
struct CompletionRow: View {
    let completion: HabitCompletion
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: RowLayout.spacing) {
            RowGlyph(icon: symbol, tint: accent)

            VStack(alignment: .leading, spacing: 3) {
                Text(habitTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !completion.note.isEmpty {
                    Text(completion.note)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Text(completion.loggedAt.formatted(date: .omitted, time: .shortened))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, RowLayout.horizontalPadding)
        .padding(.vertical, RowLayout.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Remove log", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
    }

    private var accent: Color { completion.habit?.color ?? .gray }
    private var symbol: String { completion.habit?.symbol ?? "circle.fill" }
    private var habitTitle: String { completion.habit?.title ?? "Deleted habit" }
}

extension View {
    /// Asks before a log goes, the way deleting a habit does. `pending` is the
    /// log a "Remove log" picked; `remove` runs once it is confirmed.
    func confirmsLogRemoval(
        _ pending: Binding<HabitCompletion?>,
        remove: @escaping (HabitCompletion) -> Void
    ) -> some View {
        alert(
            "Remove this log?",
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil } }
            ),
            presenting: pending.wrappedValue
        ) { completion in
            Button("Remove", role: .destructive) { remove(completion) }
            Button("Cancel", role: .cancel) {}
        } message: { completion in
            let day = completion.date
            let when = day.isToday || day.isYesterday ? day.relativeDayName.lowercased() : "on \(day.relativeDayName)"
            Text("This removes the log for \(completion.habit?.title ?? "this habit") \(when).")
        }
    }
}
