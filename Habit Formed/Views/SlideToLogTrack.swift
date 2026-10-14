import SwiftUI

/// Slide-to-log track, mirroring iOS's slide-to-answer. As the knob travels
/// its chevron turns a quarter clockwise and settles into a check, landing
/// at 75% where it arms (a tick and a small pop); let go to log, or pull
/// back to disarm. A confident
/// flick from halfway logs too. Flat: the knob is a disc a step lighter
/// than its color, the pill a soft white tint, no shadows.
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
                // The pill is what is left to slide: it shrinks behind the
                // knob, uncovering the fill it rides on.
                Capsule()
                    .fill(Color.white.opacity(isLogged ? 0 : 0.08))
                    .padding(.leading, p * maxX)

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

    /// A flat disc a step lighter than the fill it slides over, so it stays
    /// distinct without a shadow. Once logged the disc melts away and only
    /// the check stays.
    private func knob(progress p: CGFloat) -> some View {
        let stroke = StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
        return Circle()
            .fill(accent.mix(with: .white, by: 0.22))
            .opacity(isLogged ? 0 : 1)
            .overlay {
                KnobGlyph(turn: Self.ramp(p, from: 0.05, to: armRatio))
                    .stroke(.white, style: stroke)
                    .frame(width: 16, height: 16)
            }
            .frame(width: Self.knobSize, height: Self.knobSize)
            .scaleEffect(isHeld ? (isArmed ? 1.12 : 1.06) : 1)
            .motion(AppMotion.snap, value: isHeld)
            .motion(AppMotion.snap, value: isArmed)
    }

    /// 0 before `from`, 1 after `to`, eased between: the glyph starts
    /// turning as the knob leaves home and is a whole check exactly where
    /// letting go logs.
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

/// The knob's glyph: a chevron that turns a quarter clockwise into a check
/// as `turn` runs from 0 to 1. A ">" turned a quarter is a "v", and a check
/// is a "v" with one short leg and one long, so each leg keeps its angle
/// and length from the corner and only those move: one stroke rotating,
/// never two glyphs crossfading. Animatable, so an undo turns it back.
private struct KnobGlyph: Shape {
    var turn: CGFloat

    var animatableData: CGFloat {
        get { turn }
        set { turn = newValue }
    }

    // Unit square, y down. The chevron ">" and the check, each as its two
    // ends around the corner; the chevron's lower leg becomes the check's
    // short one as it turns.
    private static let chevron = (short: CGPoint(x: 0.36, y: 0.82), corner: CGPoint(x: 0.68, y: 0.5), long: CGPoint(x: 0.36, y: 0.18))
    private static let check = (short: CGPoint(x: 0.16, y: 0.54), corner: CGPoint(x: 0.4, y: 0.78), long: CGPoint(x: 0.86, y: 0.26))

    func path(in rect: CGRect) -> Path {
        let t = min(max(turn, 0), 1)
        let from = Self.chevron, to = Self.check
        // The corner rides a quarter turn about the middle, then eases onto
        // the check's corner.
        let center = CGPoint(x: 0.5, y: 0.5)
        let swung = Self.rotate(from.corner, about: center, by: .pi / 2 * t)
        let landed = Self.rotate(from.corner, about: center, by: .pi / 2)
        let corner = CGPoint(x: swung.x + (to.corner.x - landed.x) * t, y: swung.y + (to.corner.y - landed.y) * t)

        let short = Self.leg(from: (from.short, from.corner), to: (to.short, to.corner), at: t)
        let long = Self.leg(from: (from.long, from.corner), to: (to.long, to.corner), at: t)
        func point(_ offset: CGVector) -> CGPoint {
            CGPoint(x: rect.minX + (corner.x + offset.dx) * rect.width, y: rect.minY + (corner.y + offset.dy) * rect.height)
        }

        var path = Path()
        path.move(to: point(short))
        path.addLine(to: point(.zero))
        path.addLine(to: point(long))
        return path
    }

    /// A leg from the corner, its angle turning clockwise and its length
    /// easing from one glyph's to the other's.
    private static func leg(from start: (end: CGPoint, corner: CGPoint), to finish: (end: CGPoint, corner: CGPoint), at t: CGFloat) -> CGVector {
        let a = atan2(start.end.y - start.corner.y, start.end.x - start.corner.x)
        var b = atan2(finish.end.y - finish.corner.y, finish.end.x - finish.corner.x)
        while b < a { b += 2 * .pi }
        let length0 = hypot(start.end.x - start.corner.x, start.end.y - start.corner.y)
        let length1 = hypot(finish.end.x - finish.corner.x, finish.end.y - finish.corner.y)
        let angle = a + (b - a) * t
        let length = length0 + (length1 - length0) * t
        return CGVector(dx: cos(angle) * length, dy: sin(angle) * length)
    }

    private static func rotate(_ point: CGPoint, about center: CGPoint, by angle: CGFloat) -> CGPoint {
        let dx = point.x - center.x, dy = point.y - center.y
        return CGPoint(x: center.x + dx * cos(angle) - dy * sin(angle), y: center.y + dx * sin(angle) + dy * cos(angle))
    }
}
