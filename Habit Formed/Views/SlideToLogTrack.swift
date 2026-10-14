import SwiftUI

/// Slide-to-log track, mirroring iOS's slide-to-answer. As the knob travels
/// its chevron fades and a check draws itself in, finishing at 75% where it
/// arms (a tick and a small pop); let go to log, or pull back to disarm. A confident
/// flick from halfway logs too. Lit from above: the knob is a domed button
/// glowing its own color, the pill a groove with the label pressed into it.
/// Once logged the channel goes and the knob melts into the filled square,
/// leaving only its check. 44pt tall so the knob meets the hit target.
///
/// `progress` is owned by the surface the track sits on, whose fill pours
/// out of the knob as it moves (see `CompletionFill`, which finds the track
/// through `BoundsKey`), and sets it back to 0 or 1 when the log is undone
/// or made elsewhere.
struct SlideToLogTrack: View {
    let accent: Color
    let isLogged: Bool
    @Binding var progress: CGFloat
    let onComplete: () -> Void

    @State private var isArmed = false
    @GestureState private var isHeld = false

    nonisolated static let trackHeight: CGFloat = 44
    nonisolated static let knobSize: CGFloat = 36
    nonisolated static let inset: CGFloat = (trackHeight - knobSize) / 2
    private let armRatio: CGFloat = 0.75
    /// Disarms a little below the arm point, so a thumb resting on the line
    /// does not tick on and off.
    private let disarmRatio: CGFloat = 0.68
    private let flickMinRatio: CGFloat = 0.4

    var body: some View {
        GeometryReader { proxy in
            let maxX = max(proxy.size.width - Self.knobSize - Self.inset * 2, 1)
            let p = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                // The pill is what is left to slide: a groove that shrinks
                // behind the knob, uncovering the fill it rides on.
                groove
                    .opacity(isLogged ? 0 : 1)
                    .padding(.leading, p * maxX)

                // Pressed into the groove: shadowed along the top of each
                // letter, lit along the bottom.
                Text("Slide to log")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5).shadow(.inner(color: .black.opacity(0.55), radius: 0.5, y: 1)))
                    .shadow(color: .white.opacity(0.1), radius: 0, y: 0.75)
                    .opacity(max(0, 1 - p * 2))
                    .padding(.leading, Self.knobSize * 0.6)
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)

                knob(progress: p)
                    .offset(x: Self.inset + p * maxX)
                    .gesture(drag(maxX: maxX), isEnabled: !isLogged)
            }
            .frame(height: Self.trackHeight)
            .motion(AppMotion.settle, value: isLogged)
        }
        .frame(height: Self.trackHeight)
        .anchorPreference(key: BoundsKey.self, value: .bounds) { $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLogged ? "Logged today" : "Slide to log")
        .accessibilityAddTraits(isLogged ? [] : .isButton)
        .accessibilityAction {
            guard !isLogged else { return }
            Haptics.success()
            withAnimation(AppMotion.snap) { progress = 1 }
            onComplete()
        }
        .onChange(of: isLogged) { isArmed = false }
    }

    /// Sunk into the tile: shade under the top edge, a lit bottom lip.
    private var groove: some View {
        Capsule()
            .fill(Color.white.opacity(0.07).shadow(.inner(color: .black.opacity(0.4), radius: 3, y: 1.5)))
            .overlay {
                Capsule().strokeBorder(
                    LinearGradient(colors: [.black.opacity(0.2), .white.opacity(0.12)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.75
                )
            }
    }

    /// A domed button lit from above: a rim lighter on top and deeper below,
    /// a thin highlight ring inside it, a specular on the crown, and a glow
    /// of its own color where it sits. Everything but the glyph melts away
    /// once logged, so Done keeps only the check.
    private func knob(progress p: CGFloat) -> some View {
        let size = Self.knobSize
        let stroke = StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
        return ZStack {
            Circle().fill(RadialGradient(
                colors: [accent.mix(with: .white, by: 0.2), accent, accent.mix(with: .black, by: 0.12)],
                center: UnitPoint(x: 0.5, y: 0.28),
                startRadius: 0,
                endRadius: size * 0.7
            ))
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(isHeld ? 0.34 : 0.26), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.6, height: size * 0.32)
                .blur(radius: 0.6)
                .offset(y: -size * 0.24)
            Circle()
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.04), .white.opacity(0.24)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
                .padding(1.5)
            Circle().strokeBorder(
                LinearGradient(colors: [accent.mix(with: .white, by: 0.35), accent.mix(with: .black, by: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1.5
            )
        }
        .opacity(isLogged ? 0 : 1)
        .overlay {
            ZStack {
                Glyph.chevron
                    .stroke(.white, style: stroke)
                    .opacity(1 - Self.ramp(p, from: 0.04, to: 0.2))
                Glyph.check
                    .trim(from: 0, to: Self.ramp(p, from: 0.2, to: armRatio))
                    .stroke(.white, style: stroke)
            }
            .frame(width: 16, height: 16)
            .shadow(color: accent.mix(with: .black, by: 0.6).opacity(0.7), radius: 0.5, y: 0.75)
        }
        .shadow(color: .black.opacity(isLogged ? 0 : 0.3), radius: 1, y: 1)
        .shadow(
            color: accent.opacity(isLogged ? 0 : isHeld ? 0.6 : 0.4),
            radius: isHeld ? 12 : 7,
            y: isHeld ? 6 : 3
        )
        .frame(width: size, height: size)
        .scaleEffect(isHeld ? (isArmed ? 1.12 : 1.06) : 1)
        .motion(AppMotion.snap, value: isHeld)
        .motion(AppMotion.snap, value: isArmed)
    }

    /// 0 before `from`, 1 after `to`, eased between: the chevron is gone
    /// early and the check is fully drawn exactly where letting go logs.
    private static func ramp(_ value: CGFloat, from: CGFloat, to: CGFloat) -> CGFloat {
        let t = min(max((value - from) / (to - from), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private func drag(maxX: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($isHeld) { _, held, _ in held = true }
            .onChanged { value in
                let x = max(0, min(maxX, value.translation.width))
                progress = x / maxX
                if !isArmed, x >= maxX * armRatio {
                    isArmed = true
                    Haptics.tick()
                } else if isArmed, x < maxX * disarmRatio {
                    isArmed = false
                }
            }
            .onEnded { value in
                let x = max(0, min(maxX, value.translation.width))
                let flicked = x >= maxX * flickMinRatio && value.predictedEndTranslation.width >= maxX
                if isArmed || flicked {
                    // The sound plays where the log lands, which knows how
                    // far along the day is; the touch answers right here.
                    Haptics.success()
                    withAnimation(AppMotion.snap) { progress = 1 }
                    onComplete()
                } else {
                    Haptics.light()
                    withAnimation(AppMotion.snap) { progress = 0 }
                }
                isArmed = false
            }
    }
}

extension SlideToLogTrack {
    /// The track's bounds, read by the surface's fill to find the knob.
    nonisolated struct BoundsKey: PreferenceKey {
        static var defaultValue: Anchor<CGRect>? { nil }

        static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
            value = value ?? nextValue()
        }
    }

    /// Where the knob's center sits in `track` at `progress`.
    nonisolated static func knobCenter(in track: CGRect, progress: CGFloat) -> CGPoint {
        let travel = max(track.width - knobSize - inset * 2, 0)
        return CGPoint(x: track.minX + inset + knobSize / 2 + progress * travel, y: track.midY)
    }
}

/// The knob's two glyphs, drawn as strokes so the check can draw itself in
/// with `trim` (which animates when the knob springs back).
private struct Glyph: Shape {
    let points: [CGPoint]

    static let chevron = Glyph(points: [CGPoint(x: 0.36, y: 0.18), CGPoint(x: 0.68, y: 0.5), CGPoint(x: 0.36, y: 0.82)])
    static let check = Glyph(points: [CGPoint(x: 0.16, y: 0.54), CGPoint(x: 0.4, y: 0.78), CGPoint(x: 0.86, y: 0.26)])

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) })
        return path
    }
}
