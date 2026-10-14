import SwiftUI

// MARK: - Settings Row

/// The one row Settings and the report editor are built from. Put rows on a
/// `GlassRowGroup(dividerInset: RowLayout.dividerInset)`.
///
/// `ListRowLabel`'s grammar on `RowLayout`'s numbers (a neutral `RowGlyph`, a
/// semibold title, a caption, the accessory, `ListRowChevron`) plus a caption
/// that wraps to any length and a labelled-control mode, so VoiceOver hears a
/// switch once, by name, with the caption as its hint.
struct SettingsRow<Accessory: View>: View {
    enum Trailing {
        case none
        /// Pushes a page.
        case chevron
        /// Leaves the app (mail, a web page).
        case external
    }

    let title: String
    let icon: String
    var caption: String? = nil
    var trailing: Trailing = .none
    /// The accessory is a control that already carries the row's name for
    /// VoiceOver (a `labelsHidden()` switch, menu or stepper), so the visible
    /// title and caption are not read a second time.
    var accessoryIsLabelled = false
    var accessory: Accessory

    init(
        _ title: String,
        icon: String,
        caption: String? = nil,
        trailing: Trailing = .none,
        accessoryIsLabelled: Bool = false,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.icon = icon
        self.caption = caption
        self.trailing = trailing
        self.accessoryIsLabelled = accessoryIsLabelled
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: RowLayout.spacing) {
            RowGlyph(icon: icon, tint: .secondary)

            VStack(alignment: .leading, spacing: 3) {
                // `.primary`, not white: a destructive row tints the whole
                // label from outside.
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .multilineTextAlignment(.leading)
            .accessibilityHidden(accessoryIsLabelled)

            Spacer(minLength: 8)

            accessory

            switch trailing {
            case .none:
                EmptyView()
            case .chevron:
                ListRowChevron()
            case .external:
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, RowLayout.horizontalPadding)
        .padding(.vertical, RowLayout.verticalPadding)
        .frame(maxWidth: .infinity, minHeight: AppLayout.minHitTarget, alignment: .leading)
        .contentShape(.rect)
    }
}

extension SettingsRow where Accessory == EmptyView {
    init(_ title: String, icon: String, caption: String? = nil, trailing: Trailing = .none) {
        self.init(title, icon: icon, caption: caption, trailing: trailing) { EmptyView() }
    }
}

extension SettingsRow where Accessory == SettingsToggle {
    /// A switch row. The switch carries the title, and the caption as its hint.
    init(_ title: String, icon: String, caption: String? = nil, isOn: Binding<Bool>) {
        self.init(title, icon: icon, caption: caption, accessoryIsLabelled: true) {
            SettingsToggle(title: title, hint: caption, isOn: isOn)
        }
    }
}

// MARK: - Accessories

/// A row's switch: labelled for VoiceOver, hidden on screen, since the row
/// draws the title.
struct SettingsToggle: View {
    let title: String
    var hint: String?
    @Binding var isOn: Bool
    @Environment(\.appCanvas) private var canvas

    var body: some View {
        Toggle(title, isOn: $isOn)
            .labelsHidden()
            .tint(canvas.look.accent)
            .accessibilityHint(hint ?? "")
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var isOn = true

    ZStack {
        AppBackground(style: .subtle)
        GlassRowGroup(dividerInset: RowLayout.dividerInset) {
            SettingsRow("App look", icon: "paintpalette", caption: "The canvas behind every screen", trailing: .chevron)
            SettingsRow("Log sound", icon: "speaker.wave.2", caption: "A soft chime when you log a habit.", isOn: $isOn)
        }
        .padding()
    }
}
