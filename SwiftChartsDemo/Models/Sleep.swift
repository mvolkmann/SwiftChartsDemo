import Foundation

enum SleepStage: String {
    case none = ""
    case awake = "Awake"
    case light = "Light"
    case deep = "Deep"
    case rem = "REM"

    var isSleep: Bool {
        self == .light || self == .deep || self == .rem
    }
}

struct Sleep {
    let startDate: Date
    let endDate: Date
    let stage: SleepStage
    let seconds: Int
}
