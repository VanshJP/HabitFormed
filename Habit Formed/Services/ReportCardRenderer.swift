import SwiftUI
import UIKit

/// Turns a day, week or year card into the image that is sent.
/// `ImageRenderer` runs on the main actor and draws one frame, so a card
/// must not depend on glass, materials or animation.
enum ReportCardRenderer {
    /// The tallest an image may be against its width (4:5) before a chat
    /// bubble crops it: Messages and Instagram both show 4:5 whole.
    static let maxAspect: CGFloat = 1.25

    /// Drawn at 3x, at least 1170 px wide, only when the card is sent; the
    /// sheet shows the same poster live instead.
    static func render(report: DailyReport, options: ReportOptions) -> UIImage? {
        render(ReportCardView(report: report, options: options), backdrop: ReportCardView.backdrop(for: options))
    }

    static func render(recap: WeeklyRecap, options: ReportOptions) -> UIImage? {
        render(WeeklyRecapCardView(recap: recap, options: options), backdrop: ReportBackdrop(options: options))
    }

    static func render(year: YearReport, options: ReportOptions) -> UIImage? {
        render(YearReportCardView(report: year, options: options), backdrop: ReportBackdrop(options: options))
    }

    private static func render(_ card: some View, backdrop: ReportBackdrop) -> UIImage? {
        let renderer = ImageRenderer(content: ReportPosterView(backdrop: backdrop) { card })
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

// MARK: - Poster

/// A card on its backdrop, never taller than `ReportCardRenderer.maxAspect`
/// times its width: a taller card gets the backdrop widened beside it
/// instead of anything cut, so a chat bubble shows all of it. The backdrop
/// is painted edge to edge and the card's own ground is left off, so a
/// widened canvas has no seam. The sheet's preview is this same view.
struct ReportPosterView<Card: View>: View {
    let backdrop: ReportBackdrop
    @ViewBuilder let card: Card

    var body: some View {
        ReportPosterLayout(maxAspect: ReportCardRenderer.maxAspect) {
            ReportBackdropView(backdrop: backdrop)
            card.environment(\.reportPaintsCanvas, false)
        }
    }
}

/// Sizes itself to the card (its second view), widened to keep within
/// `maxAspect`; the backdrop (its first) fills it and the card sits centred.
private struct ReportPosterLayout: Layout {
    let maxAspect: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let card = subviews[1].sizeThatFits(.unspecified)
        return CGSize(width: max(card.width, card.height / maxAspect), height: card.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        let card = subviews[1].sizeThatFits(.unspecified)
        subviews[1].place(
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            anchor: .center,
            proposal: ProposedViewSize(card)
        )
    }
}
