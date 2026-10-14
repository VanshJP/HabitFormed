import SwiftUI

/// A habit's surface filling with its color, which is how Today shows done:
/// the color runs in from the leading edge until the shape is a filled
/// square. While the slide knob moves, `amount` is its progress, so in a
/// tile the edge travels just under the thumb. 0 is empty, 1 is filled.
struct CompletionFill: View {
    let color: Color
    let amount: CGFloat
    var cornerRadius: CGFloat = AppLayout.tileRadius

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LinearGradient(
                colors: [color, color.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .mask(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle().frame(width: proxy.size.width * min(max(amount, 0), 1))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension CompletionFill {
    /// What a tile or row syncs its fill to: the day shown, whether the habit
    /// is done for it, and whether it is logged today, where the slide lives.
    /// Keyed by day so a log can animate while a day change just lands.
    struct Key: Equatable {
        let day: Date
        let done: Bool
        let doneToday: Bool
    }
}
