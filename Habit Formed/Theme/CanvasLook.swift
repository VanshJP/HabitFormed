import SwiftUI

// MARK: - Canvas Look

/// The one catalogue of background art, ported from SpeakUp. Two places paint
/// it: the app canvas behind every screen (`AppCanvas`, Settings → App look)
/// and the daily report card (`ReportTheme`), so Aurora means the same Aurora
/// on both.
///
/// Not persisted: the menus own their stored raw values, so cases here can be
/// added or reordered freely. Every look is a still, because motion behind a
/// screen burns frames on wallpaper the eye stops noticing.
nonisolated enum CanvasLook: CaseIterable, Hashable, Sendable {
    case classic
    case midnight
    case mist
    case aurora
    case ember
    case depth
    case tide
    case dusk
    case noir
    case black
    case graphite
    case navy
    case plum
    case forest

    var summary: String {
        switch self {
        case .classic: return "Deep navy with soft teal light"
        case .midnight: return "Near-black navy with one faint teal glow"
        case .mist: return "Two soft fog banks across graphite"
        case .aurora: return "One soft curtain of teal and violet light"
        case .ember: return "Warm copper glow rising from below"
        case .depth: return "One soft teal well in deep navy"
        case .tide: return "Ocean blue and teal rising from below"
        case .dusk: return "Soft amber light meeting cool teal"
        case .noir: return "Graphite black with one teal slash"
        case .black: return "True black"
        case .graphite: return "Plain dark gray"
        case .navy: return "Plain deep navy"
        case .plum: return "Plain deep plum"
        case .forest: return "Plain deep green"
        }
    }
}

// MARK: - Mood

/// How hard a look pushes. The app canvas sits behind text all day; a report
/// card is a poster, so it runs at full intensity.
nonisolated enum CanvasMood: Sendable {
    /// Behind the screens: dimmer light.
    case ambient
    /// A shared card or a focus session: full intensity.
    case session

    var gain: Double { self == .session ? 1.0 : 0.90 }
}

// MARK: - Paint

extension CanvasLook {
    /// Draws the whole look in one `Canvas` pass. Everything goes through the
    /// primitives at the bottom of this file, so a background is never a stack
    /// of gradient views. All geometry is normalised against the diagonal, so
    /// a 52pt swatch is a true miniature of the full screen.
    func paint(
        into g: inout GraphicsContext,
        size: CGSize,
        mood: CanvasMood,
        tone: AppBackground.Style = .primary
    ) {
        guard size.width > 1, size.height > 1 else { return }
        let f = CanvasFrame(size: size, mood: mood)

        switch self {
        case .classic: paintClassic(&g, f, tone)
        case .midnight: paintMidnight(&g, f, tone)
        case .mist: paintMist(&g, f)
        case .aurora: paintAurora(&g, f)
        case .ember: paintEmber(&g, f)
        case .depth: paintDepth(&g, f)
        case .tide: paintTide(&g, f)
        case .dusk: paintDusk(&g, f)
        case .noir: paintNoir(&g, f)
        case .black: paintPlain(&g, f, Color(red: 0, green: 0, blue: 0))
        case .graphite: paintPlain(&g, f, Color(red: 0.115, green: 0.118, blue: 0.128))
        case .navy: paintPlain(&g, f, Color(red: 0.070, green: 0.095, blue: 0.200))
        case .plum: paintPlain(&g, f, Color(red: 0.140, green: 0.075, blue: 0.165))
        case .forest: paintPlain(&g, f, Color(red: 0.050, green: 0.120, blue: 0.095))
        }
    }
}

/// The canvas box and the mood knobs, resolved once.
private struct CanvasFrame {
    let size: CGSize
    let mood: CanvasMood

    /// Diagonal: the unit every radius is expressed in.
    var d: CGFloat { hypot(size.width, size.height) }

    /// Point at a normalised position.
    func at(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: size.width * x, y: size.height * y)
    }

    /// Glow intensity for this mood.
    func gain(_ full: Double) -> Double { full * mood.gain }
}

// MARK: - Painters

// Classic is the bar every other look is held to: a dark wash, two or three
// large low-contrast glows and a vignette. Text and glass cards sit on these,
// so a look keeps one signature shape at most.

// MARK: Classic

/// The default: deep navy, teal high light, quiet blue counterweight. Tone
/// only nudges the wash: `.subtle` sits a hair above `.primary` so a sheet
/// does not pop, `.recording` drops darker and pushes the teal.
private func paintClassic(_ g: inout GraphicsContext, _ f: CanvasFrame, _ tone: AppBackground.Style) {
    let lift: Double
    let teal: Double
    switch tone {
    case .primary: lift = 0; teal = 1
    case .subtle: lift = 0.006; teal = 0.9
    case .recording: lift = -0.014; teal = 1.45
    }

    canvasWash(&g, f.size, [
        Color(red: 0.052 + lift, green: 0.070 + lift, blue: 0.158 + lift),
        Color(red: 0.030 + lift, green: 0.044 + lift, blue: 0.102 + lift),
        Color(red: 0.028 + lift, green: 0.030 + lift, blue: 0.072 + lift),
    ], from: .topLeading, to: .bottomTrailing)

    g.blendMode = .plusLighter
    canvasGlow(&g, AppColors.brandBright, at: f.at(0.88, 0.06),
               radius: f.d * 0.46, intensity: 0.30 * teal, stretch: 1.25, angle: .degrees(-18))
    canvasGlow(&g, canvasQuietBlue, at: f.at(0.08, 0.88),
               radius: f.d * 0.42, intensity: 0.14, stretch: 1.3, angle: .degrees(14))
    canvasGlow(&g, AppColors.primary, at: f.at(0.52, 0.44),
               radius: f.d * 0.52, intensity: 0.13 * teal, stretch: 1.15)
    g.blendMode = .normal

    canvasVignette(&g, f.size, strength: 0.30)
}

// MARK: Midnight

/// Classic's darker sibling: near-black navy, one faint teal glow and a quiet
/// blue counterweight.
private func paintMidnight(_ g: inout GraphicsContext, _ f: CanvasFrame, _ tone: AppBackground.Style) {
    let lift: Double
    switch tone {
    case .primary: lift = 0
    case .subtle: lift = 0.005
    case .recording: lift = -0.006
    }

    canvasWash(&g, f.size, [
        Color(red: 0.030 + lift, green: 0.035 + lift, blue: 0.078 + lift),
        Color(red: 0.016 + lift, green: 0.020 + lift, blue: 0.048 + lift),
        Color(red: 0.008 + lift, green: 0.010 + lift, blue: 0.026 + lift),
    ])

    g.blendMode = .plusLighter
    canvasGlow(&g, AppColors.primary, at: f.at(0.80, 0.10),
               radius: f.d * 0.46, intensity: 0.15, stretch: 1.3)
    canvasGlow(&g, canvasQuietBlue, at: f.at(0.16, 0.84),
               radius: f.d * 0.42, intensity: 0.12, stretch: 1.2)
    g.blendMode = .normal

    canvasVignette(&g, f.size, strength: 0.34)
}

// MARK: Mist

/// Two fog banks, stretched flat so the field reads as weather across
/// graphite rather than orbs.
private func paintMist(_ g: inout GraphicsContext, _ f: CanvasFrame) {
    canvasWash(&g, f.size, [
        Color(red: 0.050, green: 0.058, blue: 0.074),
        Color(red: 0.028, green: 0.036, blue: 0.058),
        Color(red: 0.016, green: 0.022, blue: 0.038),
    ])

    g.blendMode = .plusLighter
    canvasGlow(&g, Color(red: 0.48, green: 0.60, blue: 0.72), at: f.at(0.26, 0.22),
               radius: f.d * 0.46, intensity: f.gain(0.24), stretch: 2.8, angle: .degrees(-6))
    canvasGlow(&g, Color(red: 0.34, green: 0.54, blue: 0.64), at: f.at(0.66, 0.66),
               radius: f.d * 0.50, intensity: f.gain(0.20), stretch: 2.8, angle: .degrees(8))
    g.blendMode = .normal

    canvasVignette(&g, f.size, strength: 0.24)
}

// MARK: Aurora

/// One soft curtain: a broad teal band leaning across the upper sky with a
/// violet wash above it.
private func paintAurora(_ g: inout GraphicsContext, _ f: CanvasFrame) {
    canvasWash(&g, f.size, [
        Color(red: 0.010, green: 0.028, blue: 0.062),
        Color(red: 0.008, green: 0.018, blue: 0.044),
        Color(red: 0.014, green: 0.012, blue: 0.036),
    ])

    g.blendMode = .plusLighter
    canvasGlow(&g, canvasMint, at: f.at(0.36, 0.30),
               radius: f.d * 0.46, intensity: f.gain(0.24), stretch: 2.8, angle: .degrees(-18))
    canvasGlow(&g, canvasViolet, at: f.at(0.72, 0.16),
               radius: f.d * 0.44, intensity: f.gain(0.20), stretch: 1.8, angle: .degrees(10))
    g.blendMode = .normal

    canvasVignette(&g, f.size, strength: 0.36, center: UnitPoint(x: 0.5, y: 0.40))
}

// MARK: Ember

/// Warm on purpose: one copper glow rising from below with a softer amber
/// heart, and a quiet blue sky so it does not read as an alert.
private func paintEmber(_ g: inout GraphicsContext, _ f: CanvasFrame) {
    canvasWash(&g, f.size, [
        Color(red: 0.034, green: 0.022, blue: 0.032),
        Color(red: 0.054, green: 0.024, blue: 0.022),
        Color(red: 0.090, green: 0.032, blue: 0.018),
    ])

    g.blendMode = .plusLighter
    canvasGlow(&g, Color(red: 0.86, green: 0.36, blue: 0.16), at: f.at(0.5, 1.06),
               radius: f.d * 0.70, intensity: f.gain(0.30), stretch: 1.5)
    canvasGlow(&g, Color(red: 1.0, green: 0.62, blue: 0.30), at: f.at(0.5, 1.02),
               radius: f.d * 0.34, intensity: f.gain(0.16), stretch: 1.8)
    canvasGlow(&g, canvasQuietBlue, at: f.at(0.74, 0.10),
               radius: f.d * 0.40, intensity: f.gain(0.10), stretch: 1.2)
    g.blendMode = .normal

    canvasVignette(&g, f.size, strength: 0.36, center: UnitPoint(x: 0.5, y: 0.86))
}

// MARK: Depth

/// One soft well: a wide teal glow with a smaller heart at the same centre.
private func paintDepth(_ g: inout GraphicsContext, _ f: CanvasFrame) {
    let center = f.at(0.5, 0.34)

    canvasWash(&g, f.size, [
        Color(red: 0.026, green: 0.032, blue: 0.070),
        Color(red: 0.016, green: 0.020, blue: 0.048),
        Color(red: 0.010, green: 0.012, blue: 0.030),
    ])

    g.blendMode = .plusLighter
    canvasGlow(&g, AppColors.brandBright, at: center, radius: f.d * 0.48, intensity: f.gain(0.20))
    canvasGlow(&g, canvasMint, at: center, radius: f.d * 0.16, intensity: f.gain(0.08))
    g.blendMode = .normal

    canvasVignette(&g, f.size, strength: 0.50, center: UnitPoint(x: 0.5, y: 0.34))
}

// MARK: Tide

/// Two soft teal bands rising from the bottom: water reading as depth.
private func paintTide(_ g: inout GraphicsContext, _ f: CanvasFrame) {
    canvasWash(&g, f.size, [
        Color(red: 0.018, green: 0.036, blue: 0.070),
        Color(red: 0.012, green: 0.028, blue: 0.054),
        Color(red: 0.008, green: 0.040, blue: 0.060),
    ], from: .top, to: .bottom)

    g.blendMode = .plusLighter
    canvasGlow(&g, AppColors.info, at: f.at(0.5, 0.72),
               radius: f.d * 0.40, intensity: f.gain(0.16), stretch: 3.4, angle: .degrees(-2))
    canvasGlow(&g, AppColors.brandBright, at: f.at(0.5, 1.0),
               radius: f.d * 0.46, intensity: f.gain(0.26), stretch: 3.4, angle: .degrees(-2))
    g.blendMode = .normal

    canvasVignette(&g, f.size, strength: 0.34, center: UnitPoint(x: 0.5, y: 0.62))
}

// MARK: Dusk

/// Soft amber light in the upper corner meeting cool teal below.
private func paintDusk(_ g: inout GraphicsContext, _ f: CanvasFrame) {
    canvasWash(&g, f.size, [
        Color(red: 0.074, green: 0.036, blue: 0.052),
        Color(red: 0.036, green: 0.030, blue: 0.066),
        Color(red: 0.012, green: 0.034, blue: 0.064),
    ], from: .topLeading, to: .bottomTrailing)

    g.blendMode = .plusLighter
    canvasGlow(&g, Color(red: 0.96, green: 0.56, blue: 0.32), at: f.at(0.20, 0.10),
               radius: f.d * 0.56, intensity: f.gain(0.24), stretch: 1.4, angle: .degrees(-20))
    canvasGlow(&g, AppColors.primary, at: f.at(0.78, 0.82),
               radius: f.d * 0.56, intensity: f.gain(0.22), stretch: 1.4)
    g.blendMode = .normal

    canvasVignette(&g, f.size, strength: 0.36, center: UnitPoint(x: 0.4, y: 0.4))
}

// MARK: Noir

/// Near-black with one soft teal slash. Maximum calm, maximum contrast.
private func paintNoir(_ g: inout GraphicsContext, _ f: CanvasFrame) {
    canvasWash(&g, f.size, [
        Color(red: 0.020, green: 0.020, blue: 0.022),
        Color(red: 0.012, green: 0.012, blue: 0.014),
        Color(red: 0.005, green: 0.005, blue: 0.006),
    ])

    g.blendMode = .plusLighter
    canvasGlow(&g, AppColors.primary, at: f.at(0.62, 0.28),
               radius: f.d * 0.56, intensity: f.gain(0.20), stretch: 3.6, angle: .degrees(-38))
    canvasGlow(&g, AppColors.brandBright, at: f.at(0.60, 0.29),
               radius: f.d * 0.22, intensity: f.gain(0.22), stretch: 4.0, angle: .degrees(-38))
    g.blendMode = .normal

    canvasVignette(&g, f.size, strength: 0.40)
}

// MARK: Plain

/// One flat colour with a hair of falloff toward the foot, for anyone who
/// wants the screen quiet. No glow, so nothing competes with the habits.
private func paintPlain(_ g: inout GraphicsContext, _ f: CanvasFrame, _ base: Color) {
    canvasWash(&g, f.size, [base, base, base.mix(with: .black, by: 0.35)])
}

// MARK: - Shared tones

private let canvasViolet = Color(red: 0.46, green: 0.28, blue: 0.90)
private let canvasMint = Color(red: 0.30, green: 0.92, blue: 0.78)
/// Quiet navy-blue counterweight, deliberately not purple.
private let canvasQuietBlue = Color(red: 0.20, green: 0.28, blue: 0.52)

// MARK: - Primitives

/// Full-bleed linear wash. The base layer of every look.
private func canvasWash(
    _ g: inout GraphicsContext,
    _ size: CGSize,
    _ colors: [Color],
    from: UnitPoint = .top,
    to: UnitPoint = .bottom
) {
    g.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .linearGradient(
            Gradient(colors: colors),
            startPoint: CGPoint(x: size.width * from.x, y: size.height * from.y),
            endPoint: CGPoint(x: size.width * to.x, y: size.height * to.y)
        )
    )
}

/// Soft light blob. `stretch` and `angle` turn it into a fog bank, a beam or
/// a slash without a second draw.
private func canvasGlow(
    _ g: inout GraphicsContext,
    _ color: Color,
    at center: CGPoint,
    radius: CGFloat,
    intensity: Double,
    stretch: CGFloat = 1,
    angle: Angle = .zero
) {
    guard radius > 0.5, intensity > 0.004 else { return }

    var layer = g
    layer.translateBy(x: center.x, y: center.y)
    if angle != .zero { layer.rotate(by: angle) }
    if stretch != 1 { layer.scaleBy(x: stretch, y: 1) }

    layer.fill(
        Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
        with: .radialGradient(
            Gradient(stops: [
                .init(color: color.opacity(intensity), location: 0),
                .init(color: color.opacity(intensity * 0.58), location: 0.26),
                .init(color: color.opacity(intensity * 0.22), location: 0.54),
                .init(color: color.opacity(intensity * 0.05), location: 0.80),
                .init(color: .clear, location: 1),
            ]),
            center: .zero, startRadius: 0, endRadius: radius
        )
    )
}

/// Darkens the edges so glass cards keep their contrast wherever they scroll.
private func canvasVignette(
    _ g: inout GraphicsContext,
    _ size: CGSize,
    strength: Double,
    center: UnitPoint = UnitPoint(x: 0.5, y: 0.45)
) {
    guard strength > 0.01 else { return }
    g.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .radialGradient(
            Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: Color.black.opacity(strength * 0.30), location: 0.60),
                .init(color: Color.black.opacity(strength), location: 1),
            ]),
            center: CGPoint(x: size.width * center.x, y: size.height * center.y),
            startRadius: 0,
            endRadius: hypot(size.width, size.height) * 0.74
        )
    )
}
