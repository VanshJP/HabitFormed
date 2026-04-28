import SwiftUI

enum AppColors {
    // MARK: - Brand

    /// Muted teal — primary brand accent. Mirrors SpeakUp.
    static let primary = Color(red: 0.051, green: 0.518, blue: 0.533) // #0D8488

    /// Warm gray — secondary accent / muted UI.
    static let accent = Color(red: 0.392, green: 0.455, blue: 0.545) // #64748B

    // MARK: - Semantic

    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue

    // MARK: - Streak heat

    /// Maps a streak length to a warm color ramp — cool teal for short
    /// streaks, ember orange/red for long streaks. Caller is responsible
    /// for deciding what counts as "long".
    static func streakColor(for streak: Int) -> Color {
        switch streak {
        case ..<1:    return Color.white.opacity(0.35)
        case 1..<3:   return primary
        case 3..<7:   return Color.teal
        case 7..<21:  return Color.orange
        case 21..<60: return Color(red: 0.96, green: 0.45, blue: 0.20)
        default:      return Color(red: 0.92, green: 0.30, blue: 0.30)
        }
    }

    // MARK: - Habit tile palette

    /// Curated tile tints that read well on the deep-navy background.
    static let tilePalette: [Color] = [
        Color(red: 0.051, green: 0.518, blue: 0.533), // teal
        Color(red: 0.20, green: 0.55, blue: 0.95),    // azure
        Color(red: 0.55, green: 0.40, blue: 0.95),    // indigo
        Color(red: 0.95, green: 0.45, blue: 0.65),    // rose
        Color(red: 0.96, green: 0.65, blue: 0.20),    // amber
        Color(red: 0.30, green: 0.80, blue: 0.55),    // mint
    ]

    // MARK: - Glass tints

    static let glassTintPrimary = Color.teal.opacity(0.10)
    static let glassTintAccent = Color.white.opacity(0.05)
    static let glassTintWarning = Color.orange.opacity(0.10)
    static let glassTintError = Color.red.opacity(0.10)
    static let glassTintSuccess = Color.green.opacity(0.10)
}

// MARK: - Hex Initializer

extension Color {
    init(hex: String) {
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
