import SwiftUI

/// Layered radial gradient background: deep navy base + ambient teal /
/// indigo / cyan orbs. Replaces plain black for premium glass-morphism feel.
struct AppBackground: View {
    var style: Style = .primary

    enum Style {
        case primary
        case subtle
        case focus
    }

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.04, blue: 0.09)

            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [tealOrb, .clear],
                center: UnitPoint(x: 0.85, y: 0.08),
                startRadius: 20,
                endRadius: 280
            )

            RadialGradient(
                colors: [indigoOrb, .clear],
                center: UnitPoint(x: 0.12, y: 0.88),
                startRadius: 10,
                endRadius: 240
            )

            RadialGradient(
                colors: [cyanGlow, .clear],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 10,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        switch style {
        case .primary:
            return [
                Color(red: 0.05, green: 0.07, blue: 0.16),
                Color(red: 0.03, green: 0.045, blue: 0.10),
                Color(red: 0.035, green: 0.035, blue: 0.08),
            ]
        case .subtle:
            return [
                Color(red: 0.045, green: 0.06, blue: 0.14),
                Color(red: 0.035, green: 0.05, blue: 0.11),
                Color(red: 0.03, green: 0.04, blue: 0.09),
            ]
        case .focus:
            return [
                Color(red: 0.02, green: 0.04, blue: 0.10),
                Color(red: 0.01, green: 0.02, blue: 0.06),
                Color(red: 0.02, green: 0.03, blue: 0.07),
            ]
        }
    }

    private var tealOrb: Color {
        switch style {
        case .primary: return Color.teal.opacity(0.12)
        case .subtle:  return Color.teal.opacity(0.10)
        case .focus:   return Color.teal.opacity(0.18)
        }
    }

    private var indigoOrb: Color {
        switch style {
        case .primary: return Color.indigo.opacity(0.09)
        case .subtle:  return Color.indigo.opacity(0.08)
        case .focus:   return Color.indigo.opacity(0.06)
        }
    }

    private var cyanGlow: Color {
        switch style {
        case .primary: return Color.cyan.opacity(0.04)
        case .subtle:  return Color.cyan.opacity(0.03)
        case .focus:   return Color.cyan.opacity(0.06)
        }
    }
}

extension View {
    func appBackground(_ style: AppBackground.Style = .primary) -> some View {
        self.background { AppBackground(style: style) }
    }
}

#Preview {
    AppBackground()
}
