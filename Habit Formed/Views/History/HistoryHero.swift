import SwiftUI

/// The top of History: the perfect-day streak as one big number, the best
/// and the last seven days under it, and the way to send the week.
struct HistoryHero: View {
    let streak: Int
    let best: Int
    /// Perfect days among the last seven.
    let perfectLastWeek: Int
    let onShareRecap: () -> Void

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(streak)")
                    .font(.displayNumeral)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(streak)))
                Text(streak == 1 ? "perfect day in a row" : "perfect days in a row")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Best \(best) · \(perfectLastWeek) of the last 7 days")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 12)

            Button(action: onShareRecap) {
                Label("Recap", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .controlChrome(in: Capsule())
                    .frame(minHeight: AppLayout.minHitTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(GlassPressStyle())
            .accessibilityLabel("Share the week's recap")
        }
        .padding(.horizontal, 4)
    }
}
