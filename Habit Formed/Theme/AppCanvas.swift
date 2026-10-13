import SwiftUI

// MARK: - App Canvas

/// The app-wide background menu: Settings → App look, painted behind every
/// screen. A thin persisted list over the shared `CanvasLook` catalogue.
///
/// Raw values are persisted (`AppPreferences.appCanvas`); do not reorder
/// existing cases. Adding a look is one new case plus one line in `look`.
nonisolated enum AppCanvas: Int, CaseIterable, Identifiable, Sendable {
    case classic = 0
    case midnight = 1
    case mist = 2
    case aurora = 3
    case ember = 4
    case depth = 5
    case tide = 6
    case dusk = 7
    case noir = 8

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .midnight: return "Midnight"
        case .mist: return "Mist"
        case .aurora: return "Aurora"
        case .ember: return "Ember"
        case .depth: return "Depth"
        case .tide: return "Tide"
        case .dusk: return "Dusk"
        case .noir: return "Noir"
        }
    }

    /// The art this entry paints.
    var look: CanvasLook {
        switch self {
        case .classic: return .classic
        case .midnight: return .midnight
        case .mist: return .mist
        case .aurora: return .aurora
        case .ember: return .ember
        case .depth: return .depth
        case .tide: return .tide
        case .dusk: return .dusk
        case .noir: return .noir
        }
    }
}

// MARK: - Look View

/// The one view that paints a canvas, in a single `Canvas` pass. No
/// `TimelineView`: every look is a still.
struct CanvasLookView: View {
    let look: CanvasLook
    var mood: CanvasMood = .ambient
    var tone: AppBackground.Style = .primary

    var body: some View {
        Canvas(opaque: true) { graphics, size in
            look.paint(into: &graphics, size: size, mood: mood, tone: tone)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
