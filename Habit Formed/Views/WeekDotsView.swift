import SwiftUI

/// Compact 7-day completion strip, oldest on the left. Logged days take the
/// habit's glyph tone; missed days are dim; today carries a ring.
struct WeekDotsView: View {
    let completionDates: [Date]
    var accent: Color = .white
    var endingOn: Date = Date()
    var dotSize: CGFloat = 7

    var body: some View {
        let days = Date.trailingDays(7, endingOn: endingOn)
        let completed = Set(completionDates.map { $0.startOfDay })

        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                Circle()
                    .fill(completed.contains(day) ? accent.glyphTone : Color.white.opacity(0.18))
                    .frame(width: dotSize, height: dotSize)
                    .overlay {
                        if day.isToday {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                                .padding(-2)
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days.filter { completed.contains($0) }.count) of the last 7 days logged")
    }
}
