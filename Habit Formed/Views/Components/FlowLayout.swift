import SwiftUI

/// Lays subviews out in lines that wrap at the proposed width. Each subview
/// is offered at most that width, so a long chip truncates instead of
/// running off the screen.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    /// Between lines; nil uses `spacing`.
    var lineSpacing: CGFloat? = nil
    /// Centres each line in the width it is placed in, as a strip of glyphs
    /// under a ring; off, every line starts at the leading edge.
    var centred = false

    struct CacheData {
        var size: CGSize
        var positions: [CGPoint]
        var sizes: [CGSize]
        /// The width of the line each subview sits on.
        var lineWidths: [CGFloat] = []
    }

    func makeCache(subviews: Subviews) -> CacheData {
        CacheData(size: .zero, positions: [], sizes: [])
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        cache = CacheData(size: result.size, positions: result.positions, sizes: result.sizes, lineWidths: result.lineWidths)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        if centred {
            // The lines this proposal makes, whatever was measured last, so
            // each one is centred as it will be drawn.
            let result = arrangeSubviews(proposal: proposal, subviews: subviews)
            cache = CacheData(size: result.size, positions: result.positions, sizes: result.sizes, lineWidths: result.lineWidths)
        } else if cache.positions.count != subviews.count {
            let result = arrangeSubviews(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
            cache = CacheData(size: result.size, positions: result.positions, sizes: result.sizes, lineWidths: result.lineWidths)
        }
        for (index, position) in cache.positions.enumerated() {
            let inset = centred && cache.lineWidths.indices.contains(index)
                ? max((bounds.width - cache.lineWidths[index]) / 2, 0)
                : 0
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x + inset, y: bounds.minY + position.y),
                proposal: ProposedViewSize(cache.sizes[index])
            )
        }
    }

    private func arrangeSubviews(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, positions: [CGPoint], sizes: [CGSize], lineWidths: [CGFloat]) {
        let maxWidth = proposal.width ?? .infinity
        let offer = ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil)
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var lineOf: [Int] = []
        var widthOfLine: [CGFloat] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(offer)
            sizes.append(size)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + (lineSpacing ?? spacing)
                lineHeight = 0
                widthOfLine.append(0)
            } else if widthOfLine.isEmpty {
                widthOfLine.append(0)
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineOf.append(widthOfLine.count - 1)

            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widthOfLine[widthOfLine.count - 1] = currentX - spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        let lineWidths = lineOf.map { widthOfLine[$0] }
        return (CGSize(width: totalWidth, height: totalHeight), positions, sizes, lineWidths)
    }
}
