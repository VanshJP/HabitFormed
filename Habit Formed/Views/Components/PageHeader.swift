import SwiftUI

// MARK: - Header Chrome

extension View {
    /// The glass every page-header control wears, such as Today's
    /// streak-and-actions capsule. Follows Settings → Look → Glass.
    func headerGlass() -> some View {
        modifier(HeaderGlassChrome())
    }

    /// Brings the navigation bar back on a page pushed from a bar-less root.
    func restoresNavigationBar() -> some View {
        toolbar(.visible, for: .navigationBar)
    }
}

/// Interactive capsule glass tinted by the App look glass setting, with the
/// header's shadow. A capsule 44pt tall and 44pt wide is a circle, so a
/// one-icon control and a multi-door capsule share it.
private struct HeaderGlassChrome: ViewModifier {
    @Environment(\.glassAppearance) private var glassAppearance

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.tint(glassAppearance.glassTint).interactive(), in: .capsule)
            .contentShape(.capsule)
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}

