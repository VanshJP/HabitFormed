import UIKit

/// One place that puts a rendered card or a text into the system share sheet,
/// ported from SpeakUp. Presents from the topmost controller, because the
/// caller (the report sheet) is itself a presented sheet.
@MainActor
enum SharePresenter {
    /// Presents `image` with an optional caption. Messages, Mail and Notes
    /// attach the caption under the image, so a friend gets both and can
    /// forward them together. Returns false when nothing could present.
    @discardableResult
    static func present(image: UIImage, message: String? = nil, onShared: (() -> Void)? = nil) -> Bool {
        var items: [Any] = [image]
        if let message, !message.isEmpty {
            items.append(message)
        }
        return present(items: items, onShared: onShared)
    }

    /// Presents any activity items. `onShared` runs only for a finished share,
    /// never for a dismissed sheet.
    @discardableResult
    static func present(items: [Any], onShared: (() -> Void)? = nil) -> Bool {
        guard let root = topViewController else { return false }
        guard canPresent(from: root) else { return false }

        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        activity.completionWithItemsHandler = { _, completed, _, _ in
            guard completed else { return }
            Task { @MainActor in onShared?() }
        }
        root.present(activity, animated: true)
        return true
    }

    /// True when nothing is already presenting and the top controller is not
    /// itself an in-flight activity sheet.
    private static func canPresent(from root: UIViewController) -> Bool {
        if root is UIActivityViewController { return false }
        if root.presentedViewController != nil { return false }
        return true
    }

    /// The topmost presented controller, not the window root. The report
    /// sheet is itself presented, so presenting on the root would fail.
    static var topViewController: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let scene else { return nil }
        let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
