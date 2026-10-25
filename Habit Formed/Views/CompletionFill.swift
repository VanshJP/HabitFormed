import SwiftUI

/// A habit's surface filling with its color, which is how Today shows done,
/// in two coats. The first, at half strength, pours out of the slide knob: a
/// circle centred on it that grows as the knob travels and reaches the
/// farthest corner as it arrives, so the thumb is always where the color
/// comes from. Once the log lands the second coat, the color itself, pours
/// out of the check where the knob came to rest. Without a knob (health,
/// timers) both grow from the bottom trailing corner, where those controls
/// sit. 0 is empty, 1 is filled.
struct CompletionFill: View {
    let color: Color
    /// The first coat. Read only in this body, so a drag redraws the fill
    /// alone, not the tile that owns the state.
    @Binding var amount: CGFloat
    /// The second coat, which only a log or an undo moves.
    let coat: CGFloat
    /// The slide track's bounds in the fill's space, when there is one.
    var track: CGRect?
    var cornerRadius: CGFloat = AppLayout.tileRadius

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(color.opacity(0.5))
                .mask { Bloom(knob: amount, growth: amount, track: track) }
            shape.fill(color)
                .mask { Bloom(knob: amount, growth: coat, track: track) }
        }
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

    /// Plays `fill` and `coat` to `state`: a log pours the second coat at
    /// once, on the quick snap, so it runs on from the knob landing; an undo
    /// takes both back together.
    static func sync(_ state: Key, fill: Binding<CGFloat>, coat: Binding<CGFloat>, animation: Animation?) {
        let target: CGFloat = state.done ? 1 : 0
        withMotion(animation) { fill.wrappedValue = target }
        withMotion(state.done && animation != nil ? AppMotion.snap : animation) { coat.wrappedValue = target }
    }
}

extension View {
    /// Fills this surface with `color`, a half-strength coat by `amount` and
    /// the full color by `coat`, pouring out of the slide knob inside it when
    /// there is one.
    func completionFill(
        _ color: Color, amount: Binding<CGFloat>, coat: CGFloat, cornerRadius: CGFloat = AppLayout.tileRadius
    ) -> some View {
        backgroundPreferenceValue(SlideToLogTrack.BoundsKey.self) { anchor in
            GeometryReader { proxy in
                CompletionFill(color: color, amount: amount, coat: coat, track: anchor.map { proxy[$0] }, cornerRadius: cornerRadius)
            }
        }
    }
}

/// The circle a coat fills, centred on the knob at `knob` and grown by
/// `growth` from the knob's disc to the farthest corner. Animatable, so an
/// undo shrinks it back into the knob as the knob slides home.
private struct Bloom: Shape {
    var knob: CGFloat
    var growth: CGFloat
    let track: CGRect?

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(knob, growth) }
        set {
            knob = newValue.first
            growth = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let a = min(max(growth, 0), 1)
        guard a > 0 else { return Path() }
        let center = track.map { SlideToLogTrack.knobCenter(in: $0, progress: min(max(knob, 0), 1)) }
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
