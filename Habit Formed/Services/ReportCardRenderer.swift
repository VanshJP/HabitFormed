import SwiftUI
import UIKit

/// Turns a report card into an image. `ImageRenderer` runs on the main actor
/// and draws one frame, so the card must not depend on glass, materials or
/// animation.
enum ReportCardRenderer {
    /// - Parameter scale: 3 for the image that leaves the app (1170 px wide);
    ///   2 is plenty for the on-screen preview and renders faster.
    static func render(report: DailyReport, content: ReportContent, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: ReportCardView(report: report, content: content))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: ReportCardView.width, height: nil)
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// The card on a 9:16 story poster (1170 × 2080 px at scale 3).
    static func renderStory(report: DailyReport, content: ReportContent, scale: CGFloat = 3) -> UIImage? {
        guard let card = render(report: report, content: content, scale: max(scale, 2)) else { return nil }
        let renderer = ImageRenderer(content: ReportStoryView(card: card, content: content))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(ReportStoryView.size)
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
