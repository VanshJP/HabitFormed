import SwiftUI

/// Slide-to-log track, mirroring iOS's slide-to-answer. As the knob travels
/// its chevron winds into clock hands showing the time right now, then
/// folds into a check, landing at 75% where it arms (a click and a small
/// pop); let go to log, or pull back to disarm. The whole way is felt: a
/// press as the knob is taken, soft steps that firm up toward the click. A confident
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
    /// True while a thumb is on the knob, so the surface can hold back its
    /// long-press menu: a pause mid-slide is not a long press.
    @Binding var isSliding: Bool
    /// "Slide to log" in the pill. A row's short track leaves it out: the
    /// knob's chevron already says which way.
    var showsLabel = true
    let onComplete: () -> Void

    @State private var isArmed = false
    /// The last step the knob passed, so each is felt once.
    @State private var step = 0
    @GestureState private var isHeld = false

    nonisolated static let trackHeight: CGFloat = 44
    nonisolated static let knobSize: CGFloat = 36
    nonisolated static let inset: CGFloat = (trackHeight - knobSize) / 2
    private let armRatio: CGFloat = 0.75
    /// Disarms a little below the arm point, so a thumb resting on the line
    /// does not tick on and off.
    private let disarmRatio: CGFloat = 0.68
    private let flickMinRatio: CGFloat = 0.4
    /// A soft step every this many points up to the arm point, then its
    /// click: by distance, so a row's short track ticks as evenly as a
    /// tile's long one instead of buzzing.
    private let stepLength: CGFloat = 14
    /// How far past the disc a touch still takes the knob.
    private static let grabSlop: CGFloat = 10

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

                if showsLabel {
                    Text("Slide to log")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55 * max(0, 1 - p * 2)))
                        .padding(.leading, Self.knobSize * 0.6)
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
                }

                knob(progress: p)
                    // A thumb-wide grab around the disc: a touch a little
                    // off it still takes hold, with no change to how it
                    // looks or where it sits.
                    .padding(Self.grabSlop)
                    .contentShape(.rect)
                    .gesture(drag(maxX: maxX), isEnabled: !isLogged)
                    .padding(-Self.grabSlop)
                    .offset(x: Self.inset + p * maxX)
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
        // From the gesture state, which resets itself even when the gesture
        // is cancelled rather than ended.
        .onChange(of: isHeld) { _, held in
            isSliding = held
            if held { Haptics.grab() }
        }
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
                ClockGlyph(
                    toClock: Self.ramp(p, from: 0.04, to: 0.38),
                    toCheck: Self.ramp(p, from: 0.5, to: armRatio),
                    time: .now
                )
                .stroke(.white, style: stroke)
                .frame(width: 16, height: 16)
            }
            .frame(width: Self.knobSize, height: Self.knobSize)
            .scaleEffect(isHeld ? (isArmed ? 1.12 : 1.06) : 1)
            .motion(AppMotion.snap, value: isHeld)
            .motion(AppMotion.snap, value: isArmed)
    }

    /// 0 before `from`, 1 after `to`, eased between: the hands reach the
    /// time a third of the way along, hold, and are a whole check exactly
    /// where letting go logs.
    private static func ramp(_ value: CGFloat, from: CGFloat, to: CGFloat) -> CGFloat {
        let t = min(max((value - from) / (to - from), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Measured on the screen: the gesture sits inside the knob's offset,
    /// so in its own space every step the knob took would come off the
    /// drag, and the knob would trail the thumb and fall short.
    private func drag(maxX: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .updating($isHeld) { _, held, _ in
                // The first touch warms the sound, so a log's chime lands
                // with its haptic.
                if !held { SoundEffects.warm() }
                held = true
            }
            .onChanged { value in
                let x = max(0, min(maxX, value.translation.width))
                progress = x / maxX
                let reached = Int(x / stepLength)
                if reached != step {
                    step = reached
                    if progress < armRatio { Haptics.slideStep(progress) }
                }
                if !isArmed, x >= maxX * armRatio {
                    isArmed = true
                    Haptics.arm()
                } else if isArmed, x < maxX * disarmRatio {
                    isArmed = false
                    Haptics.disarm()
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
                step = 0
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

/// The knob's glyph, three poses of one stroke: the chevron ">", clock
/// hands showing `time` (the knob's disc is the face), and the check. Each
/// pose is a corner and two legs, each leg an angle and a length from the
/// corner, so moving between poses swings the legs rather than crossfading
/// shapes. The legs wind clockwise from the chevron to the time, then take
/// the short way to the check. Animatable, so an undo winds it all back.
private struct ClockGlyph: Shape {
    var toClock: CGFloat
    var toCheck: CGFloat
    let time: Date

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(toClock, toCheck) }
        set {
            toClock = newValue.first
            toCheck = newValue.second
        }
    }

    /// A corner and its two legs in a unit square, y down, angles in
    /// radians from pointing right, clockwise. The short leg becomes the
    /// hour hand and then the check's short stroke.
    private struct Pose {
        var corner: CGPoint
        var short: (angle: CGFloat, length: CGFloat)
        var long: (angle: CGFloat, length: CGFloat)

        func mixed(with other: Pose, by t: CGFloat) -> Pose {
            func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * t }
            return Pose(
                corner: CGPoint(x: lerp(corner.x, other.corner.x), y: lerp(corner.y, other.corner.y)),
                short: (lerp(short.angle, other.short.angle), lerp(short.length, other.short.length)),
                long: (lerp(long.angle, other.long.angle), lerp(long.length, other.long.length))
            )
        }
    }

    private static let chevron = Pose(corner: CGPoint(x: 0.68, y: 0.5), short: (.pi * 0.75, 0.4525), long: (.pi * 1.25, 0.4525))
    private static let check = Pose(corner: CGPoint(x: 0.4, y: 0.78), short: (.pi * 1.25, 0.3394), long: (atan2(-0.52, 0.46), 0.6943))

    func path(in rect: CGRect) -> Path {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let minutes = CGFloat((parts.hour ?? 0) % 12 * 60 + (parts.minute ?? 0))
        // Clock angles count from 12; these count from 3 o'clock.
        let hour = minutes / 720 * 2 * .pi - .pi / 2
        let minute = CGFloat(parts.minute ?? 0) / 60 * 2 * .pi - .pi / 2

        let from = Self.chevron
        let clock = Pose(
            corner: CGPoint(x: 0.5, y: 0.5),
            short: (Self.clockwise(from: from.short.angle, to: hour), 0.42),
            long: (Self.clockwise(from: from.long.angle, to: minute), 0.62)
        )
        var check = Self.check
        check.short.angle = Self.nearest(to: clock.short.angle, from: check.short.angle)
        check.long.angle = Self.nearest(to: clock.long.angle, from: check.long.angle)

        let pose = from.mixed(with: clock, by: toClock).mixed(with: check, by: toCheck)
        func point(_ leg: (angle: CGFloat, length: CGFloat)) -> CGPoint {
            CGPoint(
                x: rect.minX + (pose.corner.x + cos(leg.angle) * leg.length) * rect.width,
                y: rect.minY + (pose.corner.y + sin(leg.angle) * leg.length) * rect.height
            )
        }

        var path = Path()
        path.move(to: point(pose.short))
        path.addLine(to: point((0, 0)))
        path.addLine(to: point(pose.long))
        return path
    }

    /// `angle` moved by whole turns to sit at or just after `start`.
    private static func clockwise(from start: CGFloat, to angle: CGFloat) -> CGFloat {
        var angle = angle
        while angle < start { angle += 2 * .pi }
        while angle >= start + 2 * .pi { angle -= 2 * .pi }
        return angle
    }

    /// `angle` moved by whole turns to sit closest to `reference`.
    private static func nearest(to reference: CGFloat, from angle: CGFloat) -> CGFloat {
        angle + 2 * .pi * ((reference - angle) / (2 * .pi)).rounded()
    }
}
