import SwiftUI

/// A habit's latest logs inside `HabitDetailView`, on one row group: the day,
/// the time, and the note if there is one. Long-press a row to remove it.
struct HabitHistoryGroup: View {
    let completions: [HabitCompletion]
    let accent: Color
    let onDelete: (HabitCompletion) -> Void

    var body: some View {
        GlassRowGroup(dividerInset: RowLayout.horizontalPadding) {
            ForEach(completions) { completion in
                HabitHistoryRow(completion: completion, accent: accent) {
                    onDelete(completion)
                }
            }
        }
    }
}

private struct HabitHistoryRow: View {
    let completion: HabitCompletion
    let accent: Color
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(completion.date.relativeDayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(trailing)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if !completion.note.isEmpty {
                Text(completion.note)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(3)
            }
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

    /// The logged time, plus the amount when a health log carried one. A log
    /// added later for a past day shows no time, since it was not done then.
    private var trailing: String {
        var parts: [String] = []
        if completion.loggedAt.isSameDay(as: completion.date) {
            parts.append(completion.loggedAt.formatted(date: .omitted, time: .shortened))
        }
        if completion.value != 1 {
            let v = completion.value
            let source = completion.habit?.source ?? .none
            if source != .none {
                parts.append(source.compactValue(v))
            } else {
                parts.append(v.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v))
            }
        }
        return parts.joined(separator: " · ")
    }
}
