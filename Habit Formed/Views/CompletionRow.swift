import SwiftUI

/// Single completion row used inside `HistoryView`'s timeline. Shows the
/// owning habit's color/icon plus the local time the entry was logged.
/// Long-press reveals a delete affordance.
struct CompletionRow: View {
    let completion: HabitCompletion
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.28))
                    .frame(width: 32, height: 32)
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(habitTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(loggedAtString)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            if completion.value != 1 {
                Text(formattedValue)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Remove Log", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
    }

    private var accent: Color { completion.habit?.color ?? .gray }
    private var symbol: String { completion.habit?.symbol ?? "circle.fill" }
    private var habitTitle: String { completion.habit?.title ?? "Deleted habit" }
    private var loggedAtString: String {
        completion.loggedAt.formatted(date: .omitted, time: .shortened)
    }

    private var formattedValue: String {
        let v = completion.value
        if v.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", v)
        }
        return String(format: "%.1f", v)
    }
}
