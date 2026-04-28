import UIKit

/// Centralized haptic feedback. Generators are kept as static singletons so
/// successive taps reuse the same prepared engine and stay tight.
enum Haptics {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    /// Light tap — toggles, chip selection, secondary affordances.
    static func light() {
        lightGenerator.prepare()
        lightGenerator.impactOccurred()
    }

    /// Medium tap — primary buttons, sheet open / close.
    static func medium() {
        mediumGenerator.prepare()
        mediumGenerator.impactOccurred()
    }

    /// Heavy tap — long-press confirmation, destructive intent reveal.
    static func heavy() {
        heavyGenerator.prepare()
        heavyGenerator.impactOccurred()
    }

    /// Rigid tap — used during long-press progress ramp for a "tightening"
    /// feel before the success notification fires.
    static func tick() {
        rigidGenerator.prepare()
        rigidGenerator.impactOccurred(intensity: 0.6)
    }

    /// Success — habit logged, streak extended.
    static func success() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }

    /// Warning — yellow / cautionary states.
    static func warning() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
    }

    /// Error — delete, destructive confirm.
    static func error() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.error)
    }

    /// Selection — picker / segment value change.
    static func selection() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }
}
