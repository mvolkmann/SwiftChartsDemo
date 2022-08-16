import Foundation

struct SleepMetrics: Codable {
    var ymd: String // yyyy-mm-dd
    var duration: Double
    var interruptionCount: Int
    var interruptionSeconds: Int
}
