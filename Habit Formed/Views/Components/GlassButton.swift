import SwiftUI

struct GlassButtonLabel: View {
    let title: String
    var icon: String? = nil
    var iconPosition: GlassButton.IconPosition = .left
    var style: GlassButton.GlassButtonVariant = .primary
    var size: GlassButton.GlassButtonSize = .medium
    var fullWidth: Bool = false

    var body: some View {
        labelContent
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: AppLayout.minHitTarget)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .modifier(GlassButtonChrome(style: style))
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowYOffset)
    }

    @ViewBuilder
    private var labelContent: some View {
        HStack(spacing: 8) {
            if iconPosition == .left {
                glyphSlot
            }

            Text(title)
                .font(size.font)

            if iconPosition == .right {
                glyphSlot
            }
        }
    }

    @ViewBuilder
    private var glyphSlot: some View {
        if let icon {
            iconImage(icon)
        }
    }

    private func iconImage(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: size.iconSize, weight: .semibold))
            .symbolSwap(icon)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return AppColors.inkOnLight
        case .secondary:
            return .primary
        case .outline, .danger:
            return .white
        }
    }

    private var shadowColor: Color {
        switch style {
        case .primary: return .black.opacity(0.28)
        case .secondary, .outline, .danger: return .clear
        }
    }

    private var shadowRadius: CGFloat {
        style == .primary ? 10 : 0
    }

    private var shadowYOffset: CGFloat {
        style == .primary ? 4 : 0
    }
}

private struct GlassButtonChrome: ViewModifier {
    let style: GlassButton.GlassButtonVariant

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .primary:
            content
                .background {
                    // Opaque: a pinned CTA over scrolling text would show the
                    // words through a translucent fill.
                    Capsule().fill(AppColors.solidWhite)
                }
                .clipShape(Capsule())
        case .secondary:
            // Tinted glass on the canvas. On a card, glass on glass samples
            // glass and comes out a murky band instead of a button, so the
            // secondary CTA is the painted plate at the same volume
            // (no glass on glass).
            content.controlChrome(in: Capsule())
        case .outline:
            content
                .background {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                }
        case .danger:
            content
                .background {
                    Capsule().fill(AppColors.error.opacity(0.9))
                }
                .clipShape(Capsule())
        }
    }
}

struct GlassButton: View {
    let title: String
    var icon: String? = nil
    var iconPosition: IconPosition = .left
    var style: GlassButtonVariant = .primary
    var size: GlassButtonSize = .medium
    var fullWidth: Bool = false
    let action: () -> Void

    enum IconPosition {
        case left, right
    }

    enum GlassButtonVariant {
        case primary
        case secondary
        case outline
        case danger
    }

    enum GlassButtonSize {
        case small
        case medium
        case large

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 20
            case .large: return 28
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 16
            }
        }

        var font: Font {
            switch self {
            case .small: return .subheadline.weight(.medium)
            case .medium: return .body.weight(.semibold)
            case .large: return .headline.weight(.semibold)
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 17
            case .large: return 20
            }
        }
    }

    var body: some View {
        Button(action: action) {
            GlassButtonLabel(
                title: title,
                icon: icon,
                iconPosition: iconPosition,
                style: style,
                size: size,
                fullWidth: fullWidth
            )
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(title)
    }
}

// MARK: - Press Style

/// Shared pressed-state feedback for glass controls: a subtle scale and dim,
/// spring-animated. Keeps taps feeling physical without any layout shift.
///
/// Press scale is exactly `0.96` (anything below ~0.95 feels exaggerated).
/// Under Reduce Motion the scale is skipped so state still dims without a
/// transform the user asked not to see.
struct GlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(PressFeedback(isPressed: configuration.isPressed))
    }
}

/// A button that is only words: "Undo", "Not now". Secondary text with `GlassPressStyle`'s press, so a tap shows it
/// landed without spending the page's colour on chrome. The call site keeps
/// its own font and hit-target frame.
struct TextLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .modifier(PressFeedback(isPressed: configuration.isPressed))
    }
}

extension ButtonStyle where Self == TextLinkStyle {
    static var textLink: TextLinkStyle { TextLinkStyle() }
}

/// The scale and dim both press styles share. A modifier, so it reads Reduce
/// Motion from the environment wherever a style applies it.
private struct PressFeedback: ViewModifier {
    let isPressed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? 0.96 : 1.0)
            .opacity(isPressed ? 0.85 : 1.0)
            .animation(reduceMotion ? nil : AppMotion.snap, value: isPressed)
    }
}

/// Pressed state for a row inside a `GlassRowGroup`. Scaling one row would
/// tear it away from its neighbours, so the row lights up edge to edge
/// instead, and the light fades out on release the way a table cell's does.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white.opacity(configuration.isPressed ? 0.07 : 0))
            .animation(configuration.isPressed ? nil : .easeOut(duration: 0.3), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Glass Buttons") {
    VStack(spacing: 20) {
        GlassButton(title: "Primary", icon: "checkmark", style: .primary) {}
        GlassButton(title: "Secondary", icon: "play.fill", style: .secondary) {}
        GlassButton(title: "Outline", icon: "arrow.clockwise", style: .outline) {}
        GlassButton(title: "Danger", icon: "trash", style: .danger) {}
        GlassButton(title: "Full Width", style: .primary, fullWidth: true) {}
        GlassButtonLabel(title: "Label only", icon: "play.fill", style: .primary, fullWidth: true)
        GlassCard {
            GlassButton(title: "Secondary on a card", style: .secondary, fullWidth: true) {}
        }
        Button("Not now") {}
            .font(.subheadline.weight(.medium))
            .frame(minHeight: AppLayout.minHitTarget)
            .buttonStyle(.textLink)
    }
    .padding()
    .background(AppBackground())
}
