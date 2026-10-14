import SwiftUI

/// The ✕ that leaves a full-screen session (the timer). A headline-weight
/// glyph on a 44pt glass circle.
///
/// A card's ✕ is `DismissButton` and a sheet's is `Button(role: .close)`;
/// this is the third, for a screen with no navigation bar.
struct SessionCloseButton: View {
    /// What the tap does, for VoiceOver: "Close timer".
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
                .glassCircle()
        }
        // `.plain`, not a press scale: the circle is interactive glass, which
        // answers the touch itself.
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    ZStack(alignment: .topLeading) {
        AppBackground(style: .recording)
        SessionCloseButton(label: "Close timer") {}
            .padding(AppLayout.pageHorizontal)
    }
}
