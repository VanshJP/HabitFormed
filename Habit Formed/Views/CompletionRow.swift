import SwiftUI

/// Single completion row used inside `HistoryView`'s day groups. Shows the
/// owning habit's color/icon plus the local time the entry was logged.
/// Long-press reveals a delete affordance.
struct CompletionRow: View {
    let completion: HabitCompletion
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.30))
                    .frame(width: 36, height: 36)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(habitTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(loggedAtString)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(accent)
                .font(.title3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
        "Logged at " + completion.loggedAt.formatted(date: .omitted, time: .shortened)
    }
}
