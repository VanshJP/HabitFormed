import SwiftUI

// MARK: - Heat

/// How hot a streak runs right now: an outline with no streak, banked coals
/// on a live streak today has not fed yet, a lit flame once today is done,
/// and a brighter third layer from a week on.
nonisolated enum StreakHeat: Int, Sendable {
    case cold
    case ember
    case kindling
    case blaze

    static func of(streak: Int, doneToday: Bool) -> StreakHeat {
        guard streak >= 1 else { return .cold }
        guard doneToday else { return .ember }
        return streak < 7 ? .kindling : .blaze
    }
}

// MARK: - Shape

/// The streak's flame, ported from SpeakUp: a main tongue leaning right over a
/// lower tongue on the left, drawn on an 80 × 128 grid so every layer and
/// every size shares one silhouette.
struct StreakFlameShape: Shape {
    static let aspectRatio: CGFloat = 80.0 / 128.0
    /// Where the flame's base sits across the grid; nested layers scale about
    /// it so they stay seated.
    static let baseX: CGFloat = 38.0 / 80.0

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 80
        let sy = rect.height / 128
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()
        path.move(to: p(52, 0))
        path.addCurve(to: p(80, 78), control1: p(48, 20), control2: p(80, 38))
        path.addCurve(to: p(38, 128), control1: p(80, 106), control2: p(62, 128))
        path.addCurve(to: p(0, 88), control1: p(16, 128), control2: p(0, 110))
        path.addCurve(to: p(18, 46), control1: p(0, 70), control2: p(8, 56))
        path.addCurve(to: p(28, 70), control1: p(18, 58), control2: p(22, 66))
        path.addCurve(to: p(52, 0), control1: p(26, 48), control2: p(34, 22))
        path.closeSubpath()
        return path
    }
}

// MARK: - Glyph

/// The flame drawn in layers, lit to its `StreakHeat`, with no animation. The
/// report card renders this one: `ImageRenderer` takes a single frame.
struct StreakFlameGlyph: View {
    let heat: StreakHeat

    private struct Layer {
        let scale: CGFloat
        /// Lift off the base, as a fraction of the flame's height.
        let lift: CGFloat
        let colors: [Color]
    }

    private var layers: [Layer] {
        switch heat {
        case .cold:
            return []
        case .ember:
            return [
                Layer(scale: 1, lift: 0, colors: AppColors.streakEmberOuter),
                Layer(scale: 0.5, lift: 4 / 128, colors: AppColors.streakEmberCore),
            ]
        case .kindling:
            return [
                Layer(scale: 1, lift: 0, colors: AppColors.streakFlameOuter),
                Layer(scale: 0.52, lift: 5 / 128, colors: AppColors.streakFlameCore),
            ]
        case .blaze:
            return [
                Layer(scale: 1, lift: 0, colors: AppColors.streakFlameOuter),
                Layer(scale: 0.70, lift: 3 / 128, colors: AppColors.streakFlameMiddle),
                Layer(scale: 0.40, lift: 6 / 128, colors: AppColors.streakFlameCore),
            ]
        }
    }

    var body: some View {
        let layers = layers
        let isCold = heat == .cold

        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)

            if isCold {
                let lineWidth = max(1.2, size.height * 0.08)
                let path = StreakFlameShape().path(in: bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
                context.stroke(
                    path,
                    with: .color(.white.opacity(0.35)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                return
            }

            let baseX = bounds.width * StreakFlameShape.baseX
            for layer in layers {
                let width = bounds.width * layer.scale
                let height = bounds.height * layer.scale
                let rect = CGRect(
                    x: baseX - width * StreakFlameShape.baseX,
                    y: bounds.maxY - bounds.height * layer.lift - height,
                    width: width,
                    height: height
                )
                context.fill(
                    StreakFlameShape().path(in: rect),
                    with: .linearGradient(
                        Gradient(colors: layer.colors),
                        startPoint: CGPoint(x: rect.midX, y: rect.minY),
                        endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                    )
                )
            }
        }
        .aspectRatio(StreakFlameShape.aspectRatio, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// MARK: - Flame

/// The live flame: the glyph plus one squash-and-stretch hop whenever the
/// streak or its heat moves. Decorative; the caller owns the label.
struct StreakFlame: View {
    let heat: StreakHeat
    var bounceValue: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(heat: StreakHeat, bounceValue: Int = 0) {
        self.heat = heat
        self.bounceValue = bounceValue
    }

    init(streak: Int, doneToday: Bool) {
        self.heat = .of(streak: streak, doneToday: doneToday)
        self.bounceValue = streak
    }

    var body: some View {
        StreakFlameGlyph(heat: heat)
            .keyframeAnimator(
                initialValue: CGFloat(1),
                trigger: reduceMotion ? 0 : bounceValue &* 8 &+ heat.rawValue
            ) { content, stretch in
                content.scaleEffect(x: 2 - stretch, y: stretch, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(1.2, duration: 0.16)
                    SpringKeyframe(0.9, duration: 0.14)
                    SpringKeyframe(1, duration: 0.32)
                }
            }
    }
}

// MARK: - Streak Chip

/// The perfect-day streak at the top of Today, inside the capsule it shares
/// with the add and settings buttons. Bare content: the capsule's
/// `headerGlass()` is the chrome, and the flame is the only coloured thing on
/// it.
struct StreakChip: View {
    let streak: Int
    var doneToday = true

    private var heat: StreakHeat { .of(streak: streak, doneToday: doneToday) }

    var body: some View {
        HStack(spacing: 6) {
            StreakFlame(streak: streak, doneToday: doneToday)
                .frame(height: 18)

            Text("\(streak)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: Double(streak)))
                .motion(AppMotion.snap, value: streak)
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(height: AppLayout.minHitTarget)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch heat {
        case .cold: return "No perfect-day streak yet"
        case .ember: return "\(streak) perfect days in a row. Finish today to keep it"
        case .kindling, .blaze: return "\(streak) perfect days in a row. Today is done"
        }
    }
}

#Preview("Heat") {
    ZStack {
        AppBackground()
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                ForEach([StreakHeat.cold, .ember, .kindling, .blaze], id: \.self) { heat in
                    StreakFlame(heat: heat).frame(height: 44)
                }
            }
            StreakChip(streak: 5, doneToday: false).headerGlass()
            StreakChip(streak: 12).headerGlass()
        }
    }
}
