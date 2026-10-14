import SwiftUI

/// A short "done" note that drops in from the top or bottom and leaves by
/// itself: "Copied", "Saved to Photos". The caller owns the message, the
/// timing and the transition; this is the capsule. Not `.interactive()`,
/// because a toast is not a control.
struct ConfirmationToast: View {
    let message: String
    var icon: String = "checkmark.circle.fill"

    @Environment(\.glassAppearance) private var glassAppearance

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.success)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassEffect(.regular.tint(glassAppearance.glassTint), in: .capsule)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

/// The capsule that follows a log on Today: what just happened, and one word
/// to take it back. A log by slide is fast enough to happen by accident, so
/// the way back sits where the thumb already is.
struct UndoToast: View {
    let message: String
    var tint: Color = AppColors.success
    let onUndo: () -> Void

    @Environment(\.glassAppearance) private var glassAppearance

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(tint.glyphTone)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                Haptics.light()
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
            ConfirmationToast(message: "Copied")
            UndoToast(message: "Read logged") {}
                .padding(.horizontal, 16)
            UndoToast(message: "Perfect day") {}
                .padding(.horizontal, 16)
        }
        .padding(.top, 12)
    }
}
