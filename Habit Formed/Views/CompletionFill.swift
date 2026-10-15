import SwiftUI

/// A habit's surface filling with its color, which is how Today shows done.
/// The color pours out of the slide knob: a circle centred on it that grows
/// as the knob travels and reaches the farthest corner as it arrives, so the
/// thumb is always where the color comes from. Without a knob (health,
/// timers, past days) it grows from the bottom trailing corner, where those
/// controls sit. 0 is empty, 1 is filled.
struct CompletionFill: View {
    let color: Color
    /// Read only in this body, so a drag redraws the fill alone, not the
    /// tile that owns the state.
    @Binding var amount: CGFloat
    /// The slide track's bounds in the fill's space, when there is one.
    var track: CGRect?
    var cornerRadius: CGFloat = AppLayout.tileRadius

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(color)
            .mask { Bloom(amount: amount, track: track) }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension CompletionFill {
    /// What a tile or row syncs its fill to: the day shown and whether the
    /// habit is logged on it. Keyed by day so a log can animate while a day
    /// change just lands.
    struct Key: Equatable {
        let day: Date
        let done: Bool
    }
}

extension View {
    /// Fills this surface with `color` by `amount`, pouring out of the slide
    /// knob inside it when there is one.
    func completionFill(_ color: Color, amount: Binding<CGFloat>, cornerRadius: CGFloat = AppLayout.tileRadius) -> some View {
        backgroundPreferenceValue(SlideToLogTrack.BoundsKey.self) { anchor in
            GeometryReader { proxy in
                CompletionFill(color: color, amount: amount, track: anchor.map { proxy[$0] }, cornerRadius: cornerRadius)
            }
        }
    }
}

/// The circle the color fills, animatable by `amount` so an undo shrinks it
/// back into the knob as the knob slides home.
private struct Bloom: Shape {
    var amount: CGFloat
    let track: CGRect?

    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let a = min(max(amount, 0), 1)
        guard a > 0 else { return Path() }
        let center = track.map { SlideToLogTrack.knobCenter(in: $0, progress: a) }
            ?? CGPoint(x: rect.maxX - 22, y: rect.maxY - 22)
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY),
        ]
        let reach = corners.map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? 0
        let start = SlideToLogTrack.knobSize / 2
        let radius = start + (reach - start) * a
        return Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
