import SwiftUI
import UIKit

// MARK: - Header Chrome

extension View {
    /// The glass every page-header control wears, such as Today's capsule
    /// of actions. Follows Settings → Look → Glass.
    func headerGlass() -> some View {
        modifier(HeaderGlassChrome())
    }

    /// A pushed page's top bar: a back button and the title, drawn as part
    /// of the page. The system bar stays hidden everywhere: pushed from a
    /// bar-less Today it animated in on its own track, its back button and
    /// title trailing the page. This bar is the page's, so it moves with it.
    func pageTopBar(_ title: String, back: (() -> Void)? = nil) -> some View {
        pageTopBar(title, back: back) { EmptyView() }
    }

    /// A pushed page's top bar with a control at its trailing end, such as
    /// a habit's More menu, worn in the same glass as the back button.
    /// `back` takes over the back button and turns swiping back off, for a
    /// page with something to lose, such as a form with unsaved changes.
    func pageTopBar<Trailing: View>(
        _ title: String, back: (() -> Void)? = nil, @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        navigationTitle(title)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaBar(edge: .top) { PageTopBar(title: title, back: back, trailing: trailing()) }
            .background { SwipeBackHook(allowsSwipe: back == nil) }
    }
}

/// Keeps swiping back on a page whose system bar is hidden, from the edge
/// and from anywhere in the content: UIKit's own answer for both gestures
/// turns them off with the bar. This one allows them whenever there is a
/// page to go back to (never on the root, where a swipe would wedge the
/// stack) and the swipe heads toward the trailing edge. A page that holds
/// its back button (`allowsSwipe` false) is left only by that button.
private struct SwipeBackHook: UIViewControllerRepresentable {
    let allowsSwipe: Bool

    func makeUIViewController(context: Context) -> Hook { Hook() }
    func updateUIViewController(_ hook: Hook, context: Context) { hook.allowsSwipe = allowsSwipe }

    final class Hook: UIViewController {
        var allowsSwipe = true {
            didSet { if viewIfLoaded?.window != nil { Gate.shared.allowsSwipe = allowsSwipe } }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let navigation = navigationController else { return }
            Gate.shared.navigation = navigation
            Gate.shared.allowsSwipe = allowsSwipe
            navigation.interactivePopGestureRecognizer?.delegate = Gate.shared
            navigation.interactiveContentPopGestureRecognizer?.delegate = Gate.shared
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            // The page under it may never hear it appear again.
            if !allowsSwipe { Gate.shared.allowsSwipe = true }
        }
    }

    private final class Gate: NSObject, UIGestureRecognizerDelegate {
        static let shared = Gate()
        weak var navigation: UINavigationController?
        var allowsSwipe = true

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard allowsSwipe, let navigation, navigation.viewControllers.count > 1 else { return false }
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view else { return true }
            // Toward the trailing edge only: a swipe that leans up or down
            // is a scroll.
            let velocity = pan.velocity(in: view)
            guard velocity.x > abs(velocity.y) else { return false }
            // From the content, a swipe that starts on a sideways rail
            // scrolls the rail; the edge always goes back.
            guard gestureRecognizer === navigation.interactiveContentPopGestureRecognizer else { return true }
            var hit = view.hitTest(pan.location(in: view), with: nil)
            while let current = hit {
                if let scroll = current as? UIScrollView, scroll.contentSize.width > scroll.bounds.width + 1 {
                    return false
                }
                hit = current.superview
            }
            return true
        }
    }
}

/// The back button in header glass, the title centred, and an optional
/// trailing control, in a 44pt row under the status bar where the system
/// bar sat, so a page's content starts where it always did.
private struct PageTopBar<Trailing: View>: View {
    let title: String
    let back: (() -> Void)?
    let trailing: Trailing

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, AppLayout.minHitTarget + 12)
            HStack {
                Button {
                    if let back { back() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
                        .headerGlass()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                Spacer(minLength: 0)
                trailing
            }
        }
        .padding(.horizontal, AppLayout.pageHorizontal)
        .frame(height: AppLayout.minHitTarget)
        // The system bar's gap above the content, so pages start where
        // they did under it.
        .padding(.bottom, 10)
    }
}

/// Interactive capsule glass tinted by the App look glass setting, with the
/// header's shadow. A capsule 44pt tall and 44pt wide is a circle, so a
/// one-icon control and a multi-door capsule share it.
private struct HeaderGlassChrome: ViewModifier {
    @Environment(\.glassAppearance) private var glassAppearance

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.tint(glassAppearance.glassTint).interactive(), in: .capsule)
            .contentShape(.capsule)
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}

