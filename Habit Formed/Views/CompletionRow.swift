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
                .font(.caption2.weight(.medium).monospacedDigit())
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
