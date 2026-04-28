import SwiftUI

/// Top-of-screen header — date, day-of-week, and a small completion summary
/// for today. Uses the same typography vocabulary as the tiles.
struct HeaderView: View {
    let completedToday: Int
    let totalHabits: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide)).uppercased())
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))

            HStack(alignment: .firstTextBaseline) {
                Text(Date().formatted(.dateTime.month(.wide).day()))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if totalHabits > 0 {
                    Text("\(completedToday) / \(totalHabits)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
    }
}
