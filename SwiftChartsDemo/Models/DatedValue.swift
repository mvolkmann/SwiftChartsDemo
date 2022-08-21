import Foundation

struct DatedValue: CustomStringConvertible, Identifiable {
    let date: String
    let ms: Int
    let unit: String
    let value: Double
    var animate: Bool = false

    var description: String {
        "DatedValue: \(date) \(ms) \(value) \(unit)"
    }

    let id = UUID()
}
