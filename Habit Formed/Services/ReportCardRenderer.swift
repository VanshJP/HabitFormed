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
}
