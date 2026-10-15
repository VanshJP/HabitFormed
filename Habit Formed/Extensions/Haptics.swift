import UIKit

/// Centralized haptic feedback. Generators are kept as static singletons so
/// successive taps reuse the same prepared engine and stay tight.
enum Haptics {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    /// Light tap: toggles, chip selection, secondary affordances.
    static func light() {
        lightGenerator.prepare()
        lightGenerator.impactOccurred()
    }

    /// Medium tap: primary buttons, sheet open / close.
    static func medium() {
        mediumGenerator.prepare()
        mediumGenerator.impactOccurred()
    }

    /// Heavy tap: long-press confirmation, destructive intent reveal.
    static func heavy() {
        heavyGenerator.prepare()
        heavyGenerator.impactOccurred()
    }

    // MARK: - Slide to log
    //
    // The knob's whole travel is felt: a press as it is picked up, soft
    // steps that firm up as it goes, a click where letting go logs, then
    // `success` on the log itself.

    /// The slide knob picked up: a soft press, so the thumb feels it take
    /// hold. Readies the steps and the click that follow.
    static func grab() {
        softGenerator.prepare()
        softGenerator.impactOccurred(intensity: 0.75)
        softGenerator.prepare()
        rigidGenerator.prepare()
    }

    /// The knob passing one of its steps, `progress` along its travel:
    /// faint at the start, firmer as it nears the point that logs.
    static func slideStep(_ progress: CGFloat) {
        let along = min(max(progress, 0), 1)
        softGenerator.impactOccurred(intensity: 0.3 + 0.5 * along)
        softGenerator.prepare()
    }

    /// The knob reaching the point where letting go logs: a firm click.
    static func arm() {
        rigidGenerator.impactOccurred(intensity: 1)
        rigidGenerator.prepare()
    }

    /// The knob pulled back out of that point: a lighter click back.
    static func disarm() {
        rigidGenerator.impactOccurred(intensity: 0.45)
        rigidGenerator.prepare()
    }

    /// Success: habit logged, streak extended.
    static func success() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }

    /// Perfect day: four taps rising in strength, timed to the chord that
    /// `SoundEffects.perfectDay` rolls, after the log's own success tap.
    static func celebrate() {
        mediumGenerator.prepare()
        for (i, intensity) in [0.45, 0.6, 0.8, 1.0].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12 + Double(i) * 0.06) {
                mediumGenerator.impactOccurred(intensity: intensity)
            }
        }
    }

    /// Taking back your own log: a soft tap, not a warning, since nothing
    /// went wrong.
    static func undo() {
        lightGenerator.prepare()
        lightGenerator.impactOccurred(intensity: 0.7)
    }

    /// Warning: yellow / cautionary states.
    static func warning() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
    }

    /// Error: delete, destructive confirm.
    static func error() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.error)
    }

    /// Selection: picker / segment value change.
    static func selection() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }
}
