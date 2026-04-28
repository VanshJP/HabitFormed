import SwiftUI

/// One month-grouped block of completions inside `HabitDetailView`. Each row
/// supports swipe-to-delete via a context menu so accidental logs are easy
/// to undo.
struct HabitHistoryGroup: View {
    let title: String
    let completions: [HabitCompletion]
    let accent: Color
    let onDelete: (HabitCompletion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(completions.enumerated()), id: \.element.id) { index, completion in
                    HabitHistoryRow(completion: completion, accent: accent, onDelete: { onDelete(completion) })
                    if index < completions.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .glassCard(cornerRadius: 16, tint: AppColors.glassTintAccent)
    }
}

private struct HabitHistoryRow: View {
    let completion: HabitCompletion
    let accent: Color
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.25))
                    .frame(width: 32, height: 32)
                Text(dayNumber)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(weekday)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(loggedAtString)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            if completion.value != 1 {
                Text(formattedValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }

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

    private var dayNumber: String {
        completion.date.formatted(.dateTime.day())
    }

    private var weekday: String {
        if completion.date.isToday { return "Today" }
        if completion.date.isYesterday { return "Yesterday" }
        return completion.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var loggedAtString: String {
        "Logged at " + completion.loggedAt.formatted(date: .omitted, time: .shortened)
    }

    private var formattedValue: String {
        let v = completion.value
        if v.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", v)
        }
        return String(format: "%.1f", v)
    }
}
