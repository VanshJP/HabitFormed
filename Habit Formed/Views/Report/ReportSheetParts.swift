import SwiftUI
import UIKit

// MARK: - Preview

/// The card as the sheet shows it: the card view itself, live and scaled
/// to fit, so a theme or a switch shows the moment it is tapped. The image
/// is drawn only when the card is sent (`ReportCardRenderer`). Shared by
/// the daily report and the weekly recap; `width` is the card's own.
struct ReportPreview<Card: View>: View {
    let width: CGFloat
    @ViewBuilder let card: Card

    @State private var available: CGFloat = 0
    @State private var height: CGFloat = 0

    var body: some View {
        let scale = available > 0 ? min(available / width, 1) : 1
        let shape = RoundedRectangle(cornerRadius: AppLayout.cardRadius / scale, style: .continuous)
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height * scale)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { available = $0 }
            .overlay(alignment: .top) {
                card
                    .fixedSize(horizontal: false, vertical: true)
                    .clipShape(shape)
                    .overlay { shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1 / scale) }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
                    .scaleEffect(scale, anchor: .top)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Card preview")
    }
}

// MARK: - Theme

/// The card's theme as a rail of swatches. Both cards share one stored
/// theme, so a week's recap looks like the days it sums up.
struct ReportThemeRow: View {
    @Binding var themeRaw: String

    var body: some View {
        SwatchRail(
            items: ReportTheme.allCases,
            selection: Binding(
                get: { ReportTheme(rawValue: themeRaw) ?? .classic },
                set: { themeRaw = $0.rawValue }
            ),
            name: \.displayName
        ) { theme in
            if let look = theme.look {
                CanvasLookView(look: look, mood: .session)
            } else {
                ReportPalette(theme: theme).paper
            }
        }
    }
}

// MARK: - Send

/// Text it and Share. The card goes alone, with no message typed under it,
/// so a friend gets one image they can forward as is. `render` draws the
/// full-size card at the moment of sending.
struct ReportSendBar: View {
    let render: () -> UIImage?

    var body: some View {
        HStack(spacing: 10) {
            if MessageComposer.canSend {
                GlassButton(title: "Text it", icon: "message.fill", style: .secondary, size: .large, fullWidth: true) {
                    guard let image = render() else { return }
                    Haptics.medium()
                    MessageComposer.shared.present(image: image)
                }
            }
            GlassButton(title: "Share", icon: "square.and.arrow.up", style: .primary, size: .large, fullWidth: true) {
                guard let image = render() else { return }
                Haptics.medium()
                SharePresenter.present(image: image)
            }
        }
        .padding(.horizontal, AppLayout.pageHorizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}
