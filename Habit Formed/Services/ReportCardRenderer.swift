import SwiftUI
import UIKit

/// Turns a report card or a weekly recap into an image. `ImageRenderer` runs on the main actor
/// and draws one frame, so the card must not depend on glass, materials or
/// animation.
enum ReportCardRenderer {
    /// Drawn at 3x, 1170 px wide, only when the card is sent; the sheet
    /// shows the live view instead.
    static func render(report: DailyReport, options: ReportOptions) -> UIImage? {
        let renderer = ImageRenderer(content: ReportCardView(report: report, options: options))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: ReportCardView.width, height: nil)
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// The Sunday recap card, drawn the same way.
    static func render(recap: WeeklyRecap, theme: ReportTheme) -> UIImage? {
        let renderer = ImageRenderer(content: WeeklyRecapCardView(recap: recap, theme: theme))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: WeeklyRecapCardView.width, height: nil)
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
