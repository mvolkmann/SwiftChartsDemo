import Foundation

class SleepDay: CustomStringConvertible {
    // MARK: - Initializer

    init() {
        lightSeconds = 0
        deepSeconds = 0
        remSeconds = 0
        interruptionCount = 0
        interruptionSeconds = 0
        timeToSleepSeconds = 0
        timeToOutOfBedSeconds = 0
    }

    // MARK: - Properties

    var lightSeconds: Int
    var deepSeconds: Int
    var remSeconds: Int
    var interruptionCount: Int
    var interruptionSeconds: Int
    var timeToSleepSeconds: Int
    var timeToOutOfBedSeconds: Int

    var description: String {
        "lightSeconds: \(lightSeconds)\n" +
            "deepSeconds: \(deepSeconds)\n" +
            "remSeconds: \(remSeconds)\n" +
            "interruptionSeconds: \(interruptionSeconds)\n" +
            "interruptionCount: \(interruptionCount)\n" +
            "timeToSleepSeconds: \(timeToSleepSeconds)\n" +
            "timeToOutOfBedSeconds: \(timeToOutOfBedSeconds)"
    }

    var totalSeconds: Int {
        lightSeconds + deepSeconds + remSeconds
    }
}
