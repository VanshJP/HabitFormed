import SwiftUI
import UIKit

// MARK: - Scope

/// Day, Week or Year: which card the sheet makes. One capsule of glass,
/// the picked one a solid white pill that glides to the next.
struct ReportScopePicker: View {
    @Binding var scope: ReportScope

    var body: some View {
        let scopes = ReportScope.allCases
        let index = CGFloat(scopes.firstIndex(of: scope) ?? 0)
        HStack(spacing: 0) {
            ForEach(scopes) { item in
                let isSelected = item == scope
                Button {
                    guard !isSelected else { return }
                    Haptics.selection()
                    scope = item
                } label: {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? AnyShapeStyle(AppColors.inkOnLight) : AnyShapeStyle(.secondary))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .background(alignment: .leading) {
            GeometryReader { proxy in
                let segment = proxy.size.width / CGFloat(scopes.count)
                Capsule()
                    .fill(AppColors.solidWhite)
                    .frame(width: segment, height: proxy.size.height)
                    .offset(x: segment * index)
                    .motion(AppMotion.slide, value: index)
            }
        }
        .padding(4)
        .controlChrome(in: Capsule())
        .frame(maxWidth: 340)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Theme

/// The card's theme as a rail of swatches. Every card shares one stored
/// theme, so a week's recap and the year look like the days they sum up.
struct ReportThemeRow: View {
    @Binding var themeRaw: String
    @Environment(\.appCanvas) private var canvas

    var body: some View {
        SwatchRail(
            items: ReportTheme.allCases,
            selection: Binding(
                get: { ReportTheme(rawValue: themeRaw) ?? .app },
                set: { themeRaw = $0.rawValue }
            ),
            name: \.displayName
        ) { theme in
            ReportCanvas(look: theme.look(appLook: canvas.look), paper: theme.paperColor)
        }
    }
}

// MARK: - Edit

/// Opens and closes the studio. The look is set ahead of time (Settings,
/// Report style), so sending needs none of it.
struct ReportEditButton: View {
    @Binding var isEditing: Bool

    var body: some View {
        // Done is the system's confirm, the glass check that pairs with the
        // sheet's close.
        if isEditing {
            Button(role: .confirm) { toggle() }
                .accessibilityLabel("Done editing the card")
        } else {
            Button("Edit") { toggle() }
                .accessibilityLabel("Edit the card")
        }
    }

    private func toggle() {
        Haptics.light()
        withMotion(AppMotion.settle) { isEditing.toggle() }
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
    }
}

extension View {
    /// Spacing for a bar pinned to the sheet's foot.
    func pinnedBar() -> some View {
        padding(.horizontal, AppLayout.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 8)
    }
}
