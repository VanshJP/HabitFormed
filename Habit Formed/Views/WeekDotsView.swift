import SwiftUI

/// Compact 7-day completion strip rendered as small dots, oldest on the
/// left. Filled dots use the habit's accent color; missed days are dim.
struct WeekDotsView: View {
    let completionDates: [Date]
    let accent: Color

    var body: some View {
        let days = Date.trailingDays(7)
        let completed = Set(completionDates.map { $0.startOfDay })

        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                Circle()
                    .fill(completed.contains(day) ? accent : Color.white.opacity(0.18))
                    .frame(width: 6, height: 6)
            }
        }
    }
}
