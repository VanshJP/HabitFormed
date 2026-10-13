import SwiftUI

/// One month of a habit's logs inside `HabitDetailView`: a header and one row
/// group. Long-press a row to remove a log.
struct HabitHistoryGroup: View {
    let title: String
    let completions: [HabitCompletion]
    let accent: Color
    let onDelete: (HabitCompletion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .eyebrowStyle()
                .padding(.horizontal, 4)

            GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                ForEach(completions) { completion in
                    HabitHistoryRow(completion: completion, accent: accent) {
                        onDelete(completion)
                    }
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
        HStack(alignment: .firstTextBaseline, spacing: RowLayout.spacing) {
            Text(completion.date.formatted(.dateTime.day()))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(accent.glyphTone)
                .frame(width: RowLayout.glyphColumn)

            VStack(alignment: .leading, spacing: 3) {
                Text(completion.date.relativeDayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if !completion.note.isEmpty {
                    Text(completion.note)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(3)
                }
                Text("Logged \(completion.loggedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if completion.value != 1 {
                Text(formattedValue)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
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

    private var formattedValue: String {
        let v = completion.value
        if v.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", v)
        }
        return String(format: "%.1f", v)
    }
}
