import SwiftUI

/// Colour tokens, ported from SpeakUp so both apps read as one family. Colour
/// lives in data and identity (a habit's tint, a progress ring), never in
/// chrome. Views never write a raw RGB.
enum AppColors {
    // MARK: - Brand

    /// Muted teal, the primary brand accent. Mirrors SpeakUp.
    static let primary = Color(red: 0.051, green: 0.518, blue: 0.533) // #0D8488

    /// Warm gray, used for secondary accents and muted UI.
    static let accent = Color(red: 0.392, green: 0.455, blue: 0.545) // #64748B

    /// Brighter teal, the gradient companion to `primary`.
    static let brandBright = Color(red: 0.169, green: 0.659, blue: 0.659) // #2BA8A8

    // MARK: - Semantic

    /// Vivid emerald. Completion and on-target state.
    static let success = Color(red: 0.220, green: 0.800, blue: 0.502) // #38CC80

    /// Bright amber. Caution and partial state.
    static let warning = Color(red: 0.961, green: 0.663, blue: 0.235) // #F5A93C

    /// Vivid coral red. Missed days and destructive actions.
    static let error = Color(red: 0.961, green: 0.329, blue: 0.290) // #F5544A

    /// Muted steel blue. Informational badges only.
    static let info = Color(red: 0.357, green: 0.529, blue: 0.761) // #5B87C2

    // MARK: - Progress ramp

    /// Day completion ramp shared by the week strip, the progress ring and the
    /// report, so "how much of today is done" wears one colour everywhere.
    static func progressColor(for fraction: Double, accent: Color = brandBright) -> Color {
        switch fraction {
        case ..<0.001: return Color.white.opacity(0.35)
        case ..<0.5:   return warning
        case ..<1:     return accent
        default:       return success
        }
    }

    // MARK: - Surfaces

    /// Recessed track behind any ring, meter, or progress capsule.
    static let meterTrack = Color.white.opacity(0.07)

    /// Faint lift for placeholder surfaces.
    static let surfaceLift = Color.white.opacity(0.03)

    /// Uniform hairline stroke around flat panels.
    static let cardStroke = Color.white.opacity(0.07)

    /// The one solid white: the primary `GlassButton`, a selected chip.
    /// Anything under 1.0 lets text scrolling behind a
    /// pinned control show through.
    static let solidWhite = Color.white

    /// Fill of a static well painted inside a card, such as a stat tile.
    static let wellFill = Color.white.opacity(0.06)

    /// Near-black ink for text and glyphs on the solid white surfaces.
    static let inkOnLight = Color(red: 0.07, green: 0.07, blue: 0.08)

    // MARK: - Streak

    /// The streak hero numeral, top to bottom: warm white, flame, ember.
    static let streakFlameGradient: [Color] = [
        Color(red: 1.00, green: 0.96, blue: 0.78),
        Color(red: 1.00, green: 0.62, blue: 0.18),
        Color(red: 0.95, green: 0.28, blue: 0.08),
    ]

    /// `StreakFlame` layers, each top to bottom.
    static let streakFlameOuter: [Color] = [
        Color(red: 1.00, green: 0.60, blue: 0.18),
        Color(red: 0.88, green: 0.22, blue: 0.11),
    ]
    static let streakFlameMiddle: [Color] = [
        Color(red: 1.00, green: 0.82, blue: 0.35),
        Color(red: 1.00, green: 0.54, blue: 0.12),
    ]
    static let streakFlameCore: [Color] = [
        Color(red: 1.00, green: 0.98, blue: 0.90),
        Color(red: 1.00, green: 0.88, blue: 0.54),
    ]
    /// A live streak not yet fed today: banked coals, not a flame.
    static let streakEmberOuter: [Color] = [
        Color(red: 0.48, green: 0.35, blue: 0.28),
        Color(red: 0.29, green: 0.18, blue: 0.15),
    ]
    static let streakEmberCore: [Color] = [
        Color(red: 1.00, green: 0.69, blue: 0.38),
        Color(red: 0.88, green: 0.34, blue: 0.12),
    ]

    // MARK: - Habit tile palette

    /// Identity tones for habits: SpeakUp's muted jewels, at a saturation that
    /// keeps a grid of tiles distinct without shouting on the navy canvas.
    /// The first entry is the default for a new habit. Stored as hex on the
    /// habit, so reordering or extending this list never touches saved data.
    static let tilePalette: [Color] = [
        primary,                                         // teal
        brandBright,                                     // bright teal
        info,                                            // steel blue
        Color(red: 0.349, green: 0.400, blue: 0.651),    // indigo
        Color(red: 0.549, green: 0.361, blue: 0.518),    // plum
        Color(red: 0.800, green: 0.420, blue: 0.520),    // rose
        Color(red: 0.749, green: 0.471, blue: 0.400),    // copper
        Color(red: 0.749, green: 0.576, blue: 0.318),    // amber
        Color(red: 0.451, green: 0.624, blue: 0.502),    // sage
        Color(red: 0.298, green: 0.388, blue: 0.494),    // slate
    ]

    // MARK: - Glass tints

    /// Identity tint for a whole card or tile (rule 12: 0.06).
    static func identityTint(_ color: Color) -> Color { color.opacity(0.06) }

    /// Identity tint for a featured or completed surface (rule 12: 0.10).
    static func featuredTint(_ color: Color) -> Color { color.opacity(0.10) }

    /// What a pane of glass is tinted with: Settings → Look → Glass's white
    /// lift, with `tint` (a habit's identity tint) laid over it, so a habit's
    /// tile brightens and deepens with the setting like every untinted pane
    /// and only its color sets it apart. Nil is the lift alone.
    static func glassTint(_ tint: Color?, on appearance: GlassAppearance) -> Color {
        guard let tint else { return appearance.glassTint }
        // "Over" is a weighted sum in linear light. Palette colors are plain
        // RGB, so they resolve the same in any environment.
        let top = tint.resolve(in: EnvironmentValues())
        let lift = Float(appearance.tintLift) * (1 - top.opacity)
        let opacity = top.opacity + lift
        guard opacity > 0 else { return appearance.glassTint }
        func over(_ channel: Float) -> Float { (channel * top.opacity + lift) / opacity }
        return Color(Color.Resolved(red: over(top.red), green: over(top.green), blue: over(top.blue), opacity: opacity))
    }
}

// MARK: - Identity glyph

extension Color {
    /// A habit's colour lifted a third of the way to white, so an identity
    /// glyph clears 3:1 on the dark canvas.
    var glyphTone: Color { mix(with: .white, by: 0.35) }
}

// MARK: - Hex

extension Color {
    /// Nonisolated so plain value types can resolve a stored hex off the main
    /// actor.
    nonisolated init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Hex string of the approximate sRGB color, e.g. `#0D8488`. Lossy for
    /// display-P3 colors but stable enough for SwiftData persistence of
    /// curated tile colors.
    var hexString: String {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let R = Int((r * 255).rounded())
        let G = Int((g * 255).rounded())
        let B = Int((b * 255).rounded())
        return String(format: "#%02X%02X%02X", R, G, B)
        #else
        return "#0D8488"
        #endif
    }
}
