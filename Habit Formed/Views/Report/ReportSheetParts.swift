import SwiftUI

// MARK: - Preview

/// The card as the send page shows it: the very poster that is sent
/// (`ReportPosterView`), live and scaled to the page's width, so a theme or
/// a switch shows the moment it is tapped and a card too tall for a chat
/// shows widened, as a friend will get it. The image is drawn only when the
/// card is sent (`ReportCardRenderer`).
struct ReportPreview<Card: View>: View {
    @ViewBuilder let card: Card

    @State private var available: CGFloat = 0
    @State private var size: CGSize = .zero

    var body: some View {
        let scale = available > 0 && size.width > 0 ? min(available / size.width, 1) : 1
        let shape = RoundedRectangle(cornerRadius: AppLayout.cardRadius / scale, style: .continuous)
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: size.height * scale)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { available = $0 }
            .overlay(alignment: .top) {
                card
                    .fixedSize()
                    .clipShape(shape)
                    .overlay { shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1 / scale) }
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                    .scaleEffect(scale, anchor: .top)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Card preview")
    }
}

// MARK: - Stage

/// The card while it is being edited: the whole of it, scaled to fit both
/// ways and centred, so every change shows without scrolling. Its parts
/// take taps (`reportRegion`), which open their tools below.
struct ReportStage<Card: View>: View {
    @ViewBuilder let card: Card

    @State private var size: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let fits = size.width > 0 && size.height > 0 && proxy.size.width > 0 && proxy.size.height > 0
            let scale = fits ? min(proxy.size.width / size.width, proxy.size.height / size.height, 1) : 1
            let shape = RoundedRectangle(cornerRadius: AppLayout.cardRadius / scale, style: .continuous)
            card
                .fixedSize()
                .clipShape(shape)
                .overlay { shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1 / scale) }
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .opacity(fits ? 1 : 0)
        }
    }
}

// MARK: - Thumbnail

/// A card in miniature for the layout gallery: the real card, with your day
/// on it, scaled to fit a fixed 4:5 box.
struct ReportThumbnail<Card: View>: View {
    var width: CGFloat = 92
    @ViewBuilder let card: Card

    @State private var size: CGSize = .zero

    var body: some View {
        let height = width * ReportCardRenderer.maxAspect
        let fits = size.width > 0 && size.height > 0
        let scale = fits ? min(width / size.width, height / size.height) : 1
        ZStack {
            card
                .fixedSize()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                .scaleEffect(scale)
                .opacity(fits ? 1 : 0)
        }
        .frame(width: width, height: height)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
