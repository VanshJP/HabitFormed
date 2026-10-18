import MessageUI
import UIKit
import UniformTypeIdentifiers

/// Opens Messages with the report card attached and nothing typed, so
/// texting a friend is one tap instead of a trip through the share sheet.
/// Unavailable on devices that cannot send texts (the Simulator, some iPads);
/// callers fall back to `SharePresenter` there.
@MainActor
final class MessageComposer: NSObject, MFMessageComposeViewControllerDelegate {
    static let shared = MessageComposer()

    static var canSend: Bool {
        MFMessageComposeViewController.canSendText()
    }

    /// Returns false when Messages could not be shown.
    @discardableResult
    func present(image: UIImage?, body: String? = nil) -> Bool {
        guard Self.canSend, let root = SharePresenter.topViewController else { return false }
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = self
        if let body, !body.isEmpty {
            composer.body = body
        }
        if let image,
           MFMessageComposeViewController.canSendAttachments(),
           let data = image.pngData() {
            composer.addAttachmentData(data, typeIdentifier: UTType.png.identifier, filename: "Report.png")
        }
        root.present(composer, animated: true)
        return true
    }

    nonisolated func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        // UIKit calls its delegates on the main thread.
        MainActor.assumeIsolated {
            controller.dismiss(animated: true)
        }
    }
}
