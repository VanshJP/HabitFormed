import SwiftUI

/// A vertical page scroller that cannot scroll sideways.
///
/// `ScrollView`'s axes decide which way content is allowed to grow *unbounded*.
/// They do not stop it growing the other way: if any child measures wider than
/// the viewport (a pill row pinned with `.fixedSize()`, a long unbroken word, a
/// fixed-width frame, or ordinary content at an accessibility text size), the
/// scroll view's content size grows with it and UIKit pans horizontally,
/// because a scroll view scrolls on any axis where content exceeds bounds.
/// The page ends up draggable sideways with everything cut off at the right.
/// Clamping the content to the container width makes the overflow clip instead.
///
/// The clamp also caps the column at `AppLayout.readableWidth`: in a wide iPad
/// window it centres there instead of stretching, while the scroll view itself
/// (scrolling, the edge effect) still spans the window. No scroll bar: pages
/// are short and the bar only flickers over the cards.
///
/// Never put one inside a scale transition or an animated `scaleEffect`: the
/// container-relative width never settles under the transform and the main
/// thread spins forever. Fade instead.
struct PageScrollView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.vertical) {
            // Cap inside, container width outside: a scroll view hugs its
            // content's width, so a capped content alone shrinks the whole
            // scroll view (and the canvas behind it) to the column.
            content
                .frame(maxWidth: AppLayout.readableWidth)
                .containerRelativeFrame(.horizontal)
        }
        .scrollIndicators(.hidden)
    }
}
