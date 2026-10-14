import ActivityKit
import Foundation

nonisolated struct HabitTimerAttributes: ActivityAttributes {
    var habitID: String
    var habitTitle: String
    var habitSymbol: String
    var habitColorHex: String
    var totalSeconds: Int

    nonisolated struct ContentState: Codable, Hashable {
        var endDate: Date?
        var pausedRemaining: TimeInterval?
        var isFinished: Bool
    }
}
