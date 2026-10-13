import SwiftUI

/// The ✕ on a card the user can wave off. The glyph at caption weight in a
/// 44pt target that lays out at 28pt, so the header row it sits in keeps the
/// height of its text.
struct DismissButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressStyle())
        .padding(-8)
        .accessibilityLabel(label)
    }
}
