import SwiftUI

/// The capsule that follows a log on Today: what just happened, and one word
/// to take it back. A log by slide is fast enough to happen by accident, so
/// the way back sits where the thumb already is.
struct UndoToast: View {
    let message: String
    /// A check for a log, the way back for one taken away.
    var icon = "checkmark.circle.fill"
    var tint: Color = AppColors.success
    let onUndo: () -> Void

    @Environment(\.glassAppearance) private var glassAppearance

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint.glyphTone)
                // Lands again when the toast turns into "Perfect day".
                .symbolEffect(.bounce, value: message)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                Haptics.undo()
                onUndo()
            } label: {
                Text("Undo")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 32)
                    .plateChrome(in: Capsule())
                    .frame(minHeight: AppLayout.minHitTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(GlassPressStyle())
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .glassEffect(.regular.tint(glassAppearance.glassTint), in: .capsule)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ZStack(alignment: .top) {
        AppBackground(style: .subtle)
        VStack(spacing: 16) {
            UndoToast(message: "Read logged") {}
                .padding(.horizontal, 16)
            UndoToast(message: "Perfect day") {}
                .padding(.horizontal, 16)
        }
        .padding(.top, 12)
    }
}
