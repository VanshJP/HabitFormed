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
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.55), radius: 24, y: 14)
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

/// The card's theme as a row of swatches. Both cards share one stored theme,
/// so a week's recap looks like the days it sums up.
struct ReportThemeRow: View {
    @Binding var themeRaw: String

    var body: some View {
        GlassSection("Theme") {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(ReportTheme.allCases) { theme in
                        swatch(theme)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, AppLayout.pageHorizontal, for: .scrollContent)
            .padding(.horizontal, -AppLayout.pageHorizontal)
        }
    }

    private func swatch(_ theme: ReportTheme) -> some View {
        let isSelected = themeRaw == theme.rawValue
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            themeRaw = theme.rawValue
        } label: {
            VStack(spacing: 6) {
                Group {
                    if let look = theme.look {
                        CanvasLookView(look: look, mood: .session)
                    } else {
                        ReportPalette(theme: theme).paper
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous)
                        .strokeBorder(isSelected ? Color.white.opacity(0.95) : AppColors.cardStroke, lineWidth: isSelected ? 2 : 1)
                }

                Text(theme.displayName)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            }
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
