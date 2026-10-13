import SwiftUI
import UIKit

/// The report card on a 9:16 poster for Instagram and Snapchat stories. The
/// card's own canvas fills the frame and the card floats in the middle, clear
/// of the story app's top bar and reply field.
struct ReportStoryView: View {
    let card: UIImage
    let content: ReportContent

    static let size = CGSize(width: 390, height: 390 * 16 / 9)

    /// The canvas behind the card. Clean is paper, so it sits on Midnight.
    private var look: CanvasLook {
        content.style == .clean ? .midnight : content.theme.look
    }

    var body: some View {
        ZStack {
            CanvasLookView(look: look, mood: .session)

            VStack(spacing: 18) {
                Spacer(minLength: 0)
                Image(uiImage: card)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                Spacer(minLength: 0)
                HabitFormedMark(tint: Color(hex: content.accentHex).glyphTone, ink: .white.opacity(0.7))
            }
            .padding(.horizontal, 28)
            .padding(.top, 72)
            .padding(.bottom, 44)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }
}
