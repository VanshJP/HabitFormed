import SwiftUI
import UIKit

/// Turns a report card or a weekly recap into an image. `ImageRenderer` runs on the main actor
/// and draws one frame, so the card must not depend on glass, materials or
/// animation.
enum ReportCardRenderer {
    /// - Parameter scale: 3 for the image that leaves the app (1170 px wide);
    ///   2 is plenty for the on-screen preview and renders faster.
    static func render(report: DailyReport, options: ReportOptions, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: ReportCardView(report: report, options: options))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: ReportCardView.width, height: nil)
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// The Sunday recap card, drawn the same way.
    static func render(recap: WeeklyRecap, theme: ReportTheme, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: WeeklyRecapCardView(recap: recap, theme: theme))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: WeeklyRecapCardView.width, height: nil)
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
