import SwiftUI
import UIKit

/// Turns a report card or a weekly recap into an image. `ImageRenderer` runs on the main actor
/// and draws one frame, so the card must not depend on glass, materials or
/// animation.
enum ReportCardRenderer {
    /// Drawn at 3x, 1170 px wide, only when the card is sent; the sheet
    /// shows the live view instead. A receipt is the slip alone, so it keeps
    /// the clear around its torn edges (Messages gets it as a PNG).
    static func render(report: DailyReport, options: ReportOptions) -> UIImage? {
        let renderer = ImageRenderer(content: ReportCardView(report: report, options: options))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: ReportCardView.width(for: options.layout), height: nil)
        renderer.isOpaque = options.layout != .receipt
        return renderer.uiImage
    }

    /// The Sunday recap card, drawn the same way.
    static func render(recap: WeeklyRecap, options: ReportOptions) -> UIImage? {
        let renderer = ImageRenderer(content: WeeklyRecapCardView(recap: recap, options: options))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: WeeklyRecapCardView.width, height: nil)
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
