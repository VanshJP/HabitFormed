import Foundation

/// The links widgets open, handled by `RootView`. Shared by both targets so
/// the scheme is spelled once.
nonisolated enum WidgetLink {
    static let scheme = "habitformed"
    static let reportHost = "report"
    static let recapHost = "recap"

    static let report = URL(string: "\(scheme)://\(reportHost)")
    static let recap = URL(string: "\(scheme)://\(recapHost)")
}
