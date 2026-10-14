import Foundation
import FoundationModels

/// Apple Intelligence's on-device model, used only to phrase facts the app
/// has already worked out. The math decides; the model words it. Every caller
/// keeps its own plain sentence for when this returns nil, which is most
/// devices (no Apple Intelligence, still downloading, or switched off).
enum OnDeviceModel {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    /// One short reply to `prompt`, or nil when the model is unavailable or
    /// fails. Em dashes are swapped for commas to keep the app's copy rule.
    static func phrase(_ prompt: String, instructions: String) async -> String? {
        guard isAvailable else { return nil }
        let session = LanguageModelSession(instructions: instructions)
        guard let reply = try? await session.respond(to: prompt).content else { return nil }
        let text = reply
            .replacingOccurrences(of: " \u{2014} ", with: ", ")
            .replacingOccurrences(of: "\u{2014}", with: ", ")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"")))
        return text.isEmpty ? nil : text
    }
}
