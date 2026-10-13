import SwiftUI

// MARK: - Glass Appearance

/// How untinted Liquid Glass reads on the navy canvas. Light (the default) is
/// a soft white lift; Dark drops the lift so cards sink into the canvas.
///
/// Raw values are persisted (`AppPreferences.glassAppearance`); do not reorder
/// existing cases.
nonisolated enum GlassAppearance: Int, CaseIterable, Identifiable, Sendable {
    case light = 0
    case dark = 1

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var caption: String {
        switch self {
        case .light: return "Brighter plates"
        case .dark: return "Deeper plates"
        }
    }

    /// Soft white lift for `.regular.tint(...)` on untinted surfaces.
    var glassTint: Color { Color.white.opacity(tintLift) }

    var tintLift: Double {
        switch self {
        case .light: return 0.08
        case .dark: return 0.02
        }
    }
}

// MARK: - Environment Keys

private struct GlassAppearanceKey: EnvironmentKey {
    static let defaultValue: GlassAppearance = .light
}

private struct AppCanvasKey: EnvironmentKey {
    static let defaultValue: AppCanvas = .classic
}

private struct IsOnGlassKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var glassAppearance: GlassAppearance {
        get { self[GlassAppearanceKey.self] }
        set { self[GlassAppearanceKey.self] = newValue }
    }

    var appCanvas: AppCanvas {
        get { self[AppCanvasKey.self] }
        set { self[AppCanvasKey.self] = newValue }
    }

    /// True for anything drawn inside a glass plate (`GlassCard`,
    /// `.glassCard()`). Liquid Glass samples what is behind it, so a second
    /// `glassEffect` laid on a plate renders as a murky grey band. Nested
    /// surfaces read this and paint a flat fill instead.
    var isOnGlass: Bool {
        get { self[IsOnGlassKey.self] }
        set { self[IsOnGlassKey.self] = newValue }
    }
}
