import SwiftUI

/// Lays subviews out in lines that wrap at the proposed width. Each subview
/// is offered at most that width, so a long chip truncates instead of
/// running off the screen.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    /// Between lines; nil uses `spacing`.
    var lineSpacing: CGFloat? = nil

    struct CacheData {
        var size: CGSize
        var positions: [CGPoint]
        var sizes: [CGSize]
    }

    func makeCache(subviews: Subviews) -> CacheData {
        CacheData(size: .zero, positions: [], sizes: [])
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        cache = CacheData(size: result.size, positions: result.positions, sizes: result.sizes)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        if cache.positions.count != subviews.count {
            let result = arrangeSubviews(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
            cache = CacheData(size: result.size, positions: result.positions, sizes: result.sizes)
        }
        for (index, position) in cache.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(cache.sizes[index])
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint], sizes: [CGSize]) {
        let maxWidth = proposal.width ?? .infinity
        let offer = ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil)
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
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
            }

            positions.append(CGPoint(x: currentX, y: currentY))

            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions, sizes)
    }
}
