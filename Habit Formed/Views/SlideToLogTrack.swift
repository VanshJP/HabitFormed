import SwiftUI

/// Slide-to-log track, mirroring iOS's slide-to-answer. As the knob travels
/// its chevron fades and a check draws itself in, finishing at 75% where it
/// arms (a tick and a small pop); let go to log, or pull back to disarm. A confident
/// flick from halfway logs too. The knob is the one raised thing on the
/// tile, lit from above: a contact shadow at rest, a deeper one while held.
/// Once logged the channel goes and the knob melts into the filled square,
/// leaving only its check. 44pt tall so the knob meets the hit target.
///
/// `progress` is owned by the surface the track sits on, which fills with
/// the habit's color as the knob moves (see `CompletionFill`), and sets it
/// back to 0 or 1 when the log is undone or made elsewhere.
struct SlideToLogTrack: View {
    let accent: Color
    let isLogged: Bool
    @Binding var progress: CGFloat
    let onComplete: () -> Void

    @State private var isArmed = false
    @GestureState private var isHeld = false

    static let trackHeight: CGFloat = 44
    static let knobSize: CGFloat = 36
    static let inset: CGFloat = (trackHeight - knobSize) / 2
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
                // The knob's own height, so the knob is its left end rather
                // than sitting in a lighter rim.
                Capsule()
                    .fill(Color.white.opacity(isLogged ? 0 : 0.08))
                    .frame(height: Self.knobSize)
                    .padding(.horizontal, Self.inset)

                Text("Slide to log")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55 * max(0, 1 - p * 2)))
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

    private func knob(progress p: CGFloat) -> some View {
        let stroke = StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
        return Circle()
            .fill(LinearGradient(
                colors: [accent.mix(with: .white, by: 0.18), accent],
                startPoint: .top,
                endPoint: .bottom
            ))
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
            }
            .shadow(
                color: .black.opacity(isLogged ? 0 : isHeld ? 0.32 : 0.2),
                radius: isHeld ? 7 : 2,
                y: isHeld ? 4 : 1
            )
            .frame(width: Self.knobSize, height: Self.knobSize)
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
