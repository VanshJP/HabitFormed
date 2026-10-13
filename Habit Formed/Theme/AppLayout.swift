import SwiftUI

/// Shared page rhythm (ported from SpeakUp), so every screen starts its text
/// on the same line and flipping tabs never reads as two different apps.
enum AppLayout {
    /// Horizontal inset for every root tab's scroll content.
    static let pageHorizontal: CGFloat = 16

    /// Bottom breathing room above the tab bar.
    static let pageBottom: CGFloat = 16

    /// The widest a page's column grows, page inset included. Every iPhone is
    /// narrower, so it only binds in a wide iPad window, where the column
    /// centres instead of stretching cards, footers and rows edge to edge.
    /// `PageScrollView` applies it; anything outside one uses `readableColumn()`.
    static let readableWidth: CGFloat = 700

    /// Gap between major chapters (Today's blocks, History's sections).
    static let chapterSpacing: CGFloat = 20

    /// Gap for denser list hubs (History's timeline, Settings).
    static let listSpacing: CGFloat = 16

    /// Gap from a section header to the card it introduces (`GlassSection`).
    static let headerGap: CGFloat = 10

    /// Minimum touch target. Visible chrome may be smaller; expand with
    /// `.frame` + `.contentShape` so the hit box still meets this size.
    static let minHitTarget: CGFloat = 44

    // MARK: - Surfaces
    //
    // Cards stacked on one page share one inset, so their text starts on one
    // line.

    /// Inset inside a full-width card (`GlassCard`'s default).
    static let cardPadding: CGFloat = 16

    /// Inset inside a grid tile, stat tile or half-width card.
    static let tilePadding: CGFloat = 12

    // MARK: - Corner radii
    //
    // The whole set: 24 / 20 / 16 / 12, and a capsule for chips, pills,
    // buttons and search fields.

    /// A centred modal overlay.
    static let overlayRadius: CGFloat = 24

    /// A full-width card or row group (`GlassCard`'s default).
    static let cardRadius: CGFloat = 20

    /// A grid tile, stat tile, half-width card or HUD card.
    static let tileRadius: CGFloat = 16

    /// A painted well or input inside a card.
    static let wellRadius: CGFloat = 12
}

extension View {
    /// Standard horizontal + bottom inset for a root tab's scroll column.
    func pageContentInsets() -> some View {
        self
            .padding(.horizontal, AppLayout.pageHorizontal)
            .padding(.bottom, AppLayout.pageBottom)
    }

    /// Caps a column at `AppLayout.readableWidth` and centres it in the width
    /// it was offered: a `safeAreaBar` footer, a floating drawer, a session
    /// screen's stack. The canvas behind it stays full-bleed. Frames only, so
    /// it is safe under a scale transition.
    func readableColumn() -> some View {
        frame(maxWidth: AppLayout.readableWidth)
            .frame(maxWidth: .infinity)
    }

    /// For a horizontal rail under `.scrollClipDisabled()`: tiles slide past
    /// the page inset to the column's edge and stop there, shadows intact. On
    /// iPhone that edge is the screen's; in a capped iPad column the tiles
    /// otherwise ran on into the margin and stopped where the lazy stack did.
    func railBleed() -> some View {
        mask {
            Rectangle()
                .padding(.horizontal, -AppLayout.pageHorizontal)
                .padding(.vertical, -32)
        }
    }
}
