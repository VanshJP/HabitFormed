import SwiftUI
import UIKit

// MARK: - Preview

/// The rendered card as the sheet shows it, with a placeholder while the
/// first render runs. Shared by the daily report and the weekly recap.
struct ReportPreview: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    }
                    .accessibilityLabel("Card preview")
            } else {
                RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous)
                    .fill(AppColors.surfaceLift)
                    .aspectRatio(0.7, contentMode: .fit)
                    .overlay { ProgressView().tint(.white) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
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
