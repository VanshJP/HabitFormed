import SwiftUI

// MARK: - App Background

/// App-wide canvas. Reads `appCanvas` from the environment so Settings → App
/// look re-skins every screen without each one owning a picker. The style
/// nudges Classic and Midnight; every other look keeps one mood.
struct AppBackground: View {
    var style: Style = .primary

    @Environment(\.appCanvas) private var canvas

    enum Style {
        /// Default: deep navy with soft teal light.
        case primary
        /// Darker with a stronger teal accent, for a focus session (the timer).
        case recording
        /// A hair lighter, for sheets and detail views.
        case subtle
    }

    var body: some View {
        CanvasLookView(look: canvas.look, mood: .ambient, tone: style)
            .ignoresSafeArea()
    }
}

extension View {
    /// Paints the app canvas behind the view.
    func appBackground(_ style: AppBackground.Style = .primary) -> some View {
        self.background { AppBackground(style: style) }
    }
}

#Preview {
    AppBackground()
}
