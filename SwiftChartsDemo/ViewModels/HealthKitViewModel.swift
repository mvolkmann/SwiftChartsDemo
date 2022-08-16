import HealthKit
import SwiftUI

// swiftlint:disable file_length type_body_length
final class HealthKitViewModel: ObservableObject {
    // This is a singleton class.
    static let shared = HealthKitViewModel()

    private init() {}

    // MARK: - Properties

    @Published private(set) var activeEnergyBurned: [DatedValue] = []
    @Published private(set) var appleExerciseTime: [DatedValue] = []
    // TODO: We are not getting appleMoveTime yet.
    @Published private(set) var appleMoveTime: [DatedValue] = []
    @Published private(set) var appleStandTime: [DatedValue] = []
    // This is the same as "Resting Energy".
    @Published private(set) var basalEnergyBurned: [DatedValue] = []
    @Published private(set) var bodyMass: [DatedValue] = []

    @Published var categoryScores: [String: Double] = [:]

    @Published private(set) var distanceCycling: [DatedValue] = []
    @Published private(set) var distanceWalkingRunning: [DatedValue] = []
    @Published private(set) var distanceWheelchair: [DatedValue] = []
    @Published private(set) var environmentalAudioExposure: [DatedValue] = []
    @Published private(set) var flightsClimbed: [DatedValue] = []
    @Published private(set) var haveSleepData = false
    @Published private(set) var headphoneAudioExposure: [DatedValue] = []
    @Published private(set) var heartRate: [DatedValue] = []
    // SDNN stands for Standard Deviation of Normal Normal? (NN) intervals.
    @Published private(set) var heartRateVariabilitySDNN: [DatedValue] = []
    @Published private(set) var highHeartRateEvents: [DatedValue] = []
    @Published private(set) var irregularHeartRhythmEvents: [DatedValue] = []
    @Published private(set) var leanBodyMass: [DatedValue] = []
    @Published private(set) var lowHeartRateEvents: [DatedValue] = []
    @Published private(set) var numberOfTimesFallen: [DatedValue] = []
    @Published private(set) var oxygenSaturation: [DatedValue] = []
    @Published private(set) var pushCount: [DatedValue] = []
    @Published private(set) var respiratoryRate: [DatedValue] = []
    @Published private(set) var restingHeartRate: [DatedValue] = []
    @Published private(set) var sixMinuteWalkTestDistance: [DatedValue] = []
    @Published private(set) var sleepDuration: [DatedValue] = []
    @Published private(set) var sleepInterruptionCount: [DatedValue] = []
    @Published private(set) var sleepInterruptionDuration: [DatedValue] = []
    @Published private(set) var sleepScore: [DatedValue] = []
    @Published private(set) var stairAscentSpeed: [DatedValue] = []
    @Published private(set) var stairDescentSpeed: [DatedValue] = []
    @Published private(set) var stepCount: [DatedValue] = []
    @Published private(set) var vo2Max: [DatedValue] = []
    @Published private(set) var walkingAsymmetryPercentage: [DatedValue] = []
    @Published private(set) var walkingDoubleSupportPercentage: [DatedValue] = []
    @Published private(set) var walkingHeartRateAverage: [DatedValue] = []
    @Published private(set) var walkingSpeed: [DatedValue] = []
    @Published private(set) var walkingSteadiness: [DatedValue] = []
    @Published private(set) var walkingStepLength: [DatedValue] = []

    let collectionNames = [
        "activeEnergyBurned",
        "appleExerciseTime",
        "appleMoveTime",
        "appleStandTime",
        "basalEnergyBurned",
        "bodyMass",
        "distanceCycling",
        "distanceWalkingRunning",
        "distanceWheelchair",
        "environmentalAudioExposure",
        "flightsClimbed",
        "headphoneAudioExposure",
        "heartRate",
        "heartRateVariabilitySDNN",
        "highHeartRateEvents",
        "irregularHeartRhythmEvents",
        "leanBodyMass",
        "lowHeartRateEvents",
        "numberOfTimesFallen",
        "oxygenSaturation",
        "pushCount",
        "respiratoryRate",
        "restingHeartRate",
        "sixMinuteWalkTestDistance",
        "sleepDuration",
        "sleepInterruptions",
        "sleepScore",
        "stairAscentSpeed",
        "stairDescentSpeed",
        "stepCount",
        "vo2Max",
        "walkingAsymmetryPercentage",
        "walkingDoubleSupportPercentage",
        "walkingHeartRateAverage",
        "walkingSpeed",
        "walkingSteadiness",
        "walkingStepLength"
    ]

    var deviceId: String?

    var store = HealthStore()

    // MARK: - Instance Methods

    private func categorizeSleepDays(_ sleepDays: [Date: SleepDay]) {
        let dates = sleepDays.keys.sorted()

        DispatchQueue.main.async {
            var allSleepMetrics: [SleepMetrics] = []

            for date in dates {
                let sleepDay = sleepDays[date]!

                let ymd = date.ymd
                // Convert seconds to hours.
                let duration = Double(sleepDay.totalSeconds) / 60.0 / 60.0
                let interruptionCount = sleepDay.interruptionCount
                let metrics = SleepMetrics(
                    ymd: ymd,
                    duration: duration,
                    interruptionCount: interruptionCount,
                    interruptionSeconds: sleepDay.interruptionSeconds
                )
                allSleepMetrics.append(metrics)

                self.sleepDuration.append(DatedValue(
                    date: date.ymdhms,
                    ms: date.milliseconds,
                    unit: "hour",
                    value: duration
                ))
                self.sleepInterruptionCount.append(DatedValue(
                    date: date.ymdhms,
                    ms: date.milliseconds,
                    unit: "count",
                    value: Double(interruptionCount)
                ))
                self.sleepInterruptionDuration.append(DatedValue(
                    date: date.ymdhms,
                    ms: date.milliseconds,
                    unit: "min", // consistent with HKUnit unitText
                    // Convert seconds to minutes.
                    value: Double(sleepDay.interruptionSeconds) / 60.0
                ))
            }
        }
    }

    // Removes duplicate samples.
    // We see these for some awake sleep stages.
    func dedupe(samples: [HKSample]) -> [HKSample] {
        guard samples.count > 0 else { return [] }

        var previousSample = samples.first!
        var deduped: [HKSample] = [previousSample]

        var previousStage = getSleepStage(sample: previousSample)
        for sample in samples.dropFirst() {
            let stage = getSleepStage(sample: sample)
            if stage != previousStage ||
                sample.startDate != previousSample.startDate ||
                sample.endDate != previousSample.endDate {
                deduped.append(sample)
            }
            previousSample = sample
            previousStage = stage
        }

        return deduped
    }

    // Gets specific data from HealthKit.
    func getHealthKitData(
        identifier: HKQuantityTypeIdentifier,
        startDate: Date? = nil,
        endDate: Date? = nil,
        frequency: Frequency? = nil,
        quantityFunction: (HKStatistics) -> HKQuantity?
    ) async throws -> [DatedValue] {
        guard let metric = Metrics.shared.map[identifier] else {
            throw "metric \(identifier.rawValue) not found"
        }

        let frequencyToUse = frequency ?? metric.frequency

        let interval =
        frequencyToUse == .minute ? DateComponents(minute: 1) :
        frequencyToUse == .hour ? DateComponents(hour: 1) :
        DateComponents(day: 1)

        let collection = try await store.queryQuantityCollection(
            typeId: metric.identifier,
            options: metric.option,
            startDate: startDate,
            endDate: endDate,
            interval: interval
        )

        return collection.map { data -> DatedValue in
            let date = data.startDate
            let quantity = quantityFunction(data)
            let value = quantity?.doubleValue(for: metric.unit) ?? 0
            return DatedValue(
                date: metric.frequency == .day ? date.ymd : date.ymdhms,
                ms: date.milliseconds,
                unit: metric.unit.unitString,
                value: value
            )
        }
    }

    // Gets the last 10 events of a given type.
    private func getHealthKitEvents(
        identifier: HKCategoryTypeIdentifier
    ) async throws -> [DatedValue] {
        let categoryType = HKObjectType.categoryType(forIdentifier: identifier)!

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: Date().daysAgo(10),
                end: nil
            )
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: 10, // TODO: Is this limit okay?
                sortDescriptors: []
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let results = results
                else {
                    continuation.resume(returning: [])
                    return
                }

                let newValue = results.map { result -> DatedValue in
                    let date = result.startDate
                    var value = 0.0
                    if let threshold = result.metadata?[HKMetadataKeyHeartRateEventThreshold] {
                        // threshold type is Any.
                        let text = String(describing: threshold)
                        if let number = text.split(separator: " ").first {
                            value = Double(number) ?? 0.0
                        }
                    }
                    return DatedValue(
                        date: date.ymdhms,
                        ms: date.milliseconds,
                        unit: "count",
                        value: value
                    )
                }

                continuation.resume(returning: newValue)
            }

            HKHealthStore().execute(query)
        }
    }

    private func getSleepData(startDate: Date?) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let categoryType = HKCategoryType(.sleepAnalysis)
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: nil
            )
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: 0,
                sortDescriptors: [
                    NSSortDescriptor(
                        key: HKSampleSortIdentifierStartDate,
                        ascending: true
                    )
                ]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let samples = samples else {
                    continuation.resume()
                    return
                }

                // This is a Dictionary with Date keys and SleepDay values
                // for the corresponding date.
                let sleepDays = self.getSleepDays(samples: samples)

                self.categorizeSleepDays(sleepDays)

                DispatchQueue.main.async {
                    self.haveSleepData = true
                }
                continuation.resume()
            }

            HKHealthStore().execute(query)
        }
    }

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    private func getSleepDays(samples: [HKSample]) -> [Date: SleepDay] {
        guard samples.count > 0 else { return [:] }

        var previousDate: Date?
        var previousSample: HKSample?
        var previousSeconds = 0
        var previousStage: SleepStage?

        var sleepDays: [Date: SleepDay] = [:]

        let dedupedSamples = dedupe(samples: samples)
        // let dedupedSamples = samples // keeps duplicates

        /* For debugging
         for sample in dedupedSamples {
         let stage = getSleepStage(sample: sample)
         let seconds = Int(sample.endDate.timeIntervalSince(sample.startDate))
         print("stage: \(stage); start: \(sample.startDate.ymdhm); " +
         "end: \(sample.endDate.ymdhm) seconds: \(seconds)")
         }
         */

        for (index, sample) in dedupedSamples.enumerated() {
            // If this sample doesn't have a sleep stage,
            // skip to the next sample.
            let stage = getSleepStage(sample: sample)
            if stage == .none { continue }

            let startDate = sample.startDate
            let seconds = Int(sample.endDate.timeIntervalSince(startDate))

            // Determine the date associated with this sleep span.
            // If the time is before 10 AM,
            // assign it to the previous day.
            var date = startDate.hour < 10 ? startDate.yesterday : startDate
            date = date.withoutTime

            // Find the SleepDay object for this date.
            let found = sleepDays[date]
            let sleepDay = found ?? SleepDay()

            if found == nil { // first sample for this date
                // Set timeToOutOfBed for the previous day.
                if let previousStage = previousStage, previousStage.isSleep {
                    if let previousDate = previousDate,
                       let previousSleepDay = sleepDays[previousDate] {
                        previousSleepDay.timeToOutOfBedSeconds = previousSeconds
                    }
                }

                sleepDays[date] = sleepDay
                if stage == .awake { // of first sample from today
                    sleepDay.timeToSleepSeconds = seconds
                }
            }

            // Update the SleepDay object for this date.
            switch stage {
            case .none:
                break

            case .awake:
                let nextSample = index < dedupedSamples.count - 1 ?
                dedupedSamples[index + 1] : nil

                if let previousSample = previousSample, let nextSample = nextSample {
                    // If the previous and next samples are
                    // immediately before and after this one ...
                    if previousSample.endDate == sample.startDate,
                       sample.endDate == nextSample.startDate {
                        // If the previous and next samples
                        // are both are kinds of sleep ...
                        let previousStage = getSleepStage(sample: previousSample)
                        let nextStage = getSleepStage(sample: nextSample)
                        if previousStage.isSleep, nextStage.isSleep {
                            sleepDay.interruptionCount += 1
                            sleepDay.interruptionSeconds += seconds
                        }
                    }
                }

            case .light:
                sleepDay.lightSeconds += seconds

            case .deep:
                sleepDay.deepSeconds += seconds

            case .rem:
                sleepDay.remSeconds += seconds
            } // end of switch

            previousDate = date
            previousSample = sample
            previousSeconds = seconds
            previousStage = stage
        }

        // print("sleepDays = \(sleepDays)")

        return sleepDays
    }

    private func getSleepStage(sample: HKSample) -> SleepStage {
        // sample is actually an HKCategorySample object.
        // It has a "value" property which can have the following sleep values:
        // 0 = inBed
        // 1 = asleepUnspecified
        // 2 = awake
        // 3 = asleepCore
        // 4 = asleepDeep
        // 5 = asleepREM
        //
        // We currently only get the values 0 to 2.
        // The values 3 and above are being added in iOS 16.
        //
        // Withings adds the metadata property "Sleep Stage"
        // which has the values "none", "awake", "light", "deep", and "rem".
        // Withings could change metadata at any time without giving notice
        // because it is the schema for their metadata
        // and is not publicly documented.
        // HealthKit is an official Apple public SDK,
        // so they will give clear guidance on changes,
        // such as the upcoming change in the enum values described above.
        //
        // TODO: Perhaps when iOS 16 is out of beta, we should use the
        // TODO: value property instead of the "Sleep Stage" metadata property.
        SleepStage(
            rawValue: sample.metadata?["Sleep Stage"] as? String ?? ""
        )!
    }

    func load() async {
        do {
            // Request permission from the user to access HealthKit data.
            // If they have already granted permission,
            // they will not be prompted again.
            try await store.requestAuthorization()

            try await loadHealthKitData()
        } catch {
            handleError("HealthKitViewModel.load", error)
        }
    }

    // This method must run on the main dispatch queue
    // because it updates @Published variables.
    @MainActor
    // swiftlint:disable function_body_length
    private func loadHealthKitData() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            handleError(
                "HealthKitViewModel.loadHealthKitData",
                "HealthKit data not available"
            )
            return
        }

        let last3Months = Date().monthsAgo(3)

        // We always want sleep data for the past three months
        // because the sleep charts require that.
        try await getSleepData(startDate: last3Months)

        // Get active energy burned per day.
        activeEnergyBurned = try await getHealthKitData(
            identifier: .activeEnergyBurned,
            frequency: .hour
        ) { data in data.sumQuantity() }
        // print("activeEnergyBurned = \(activeEnergyBurned)")

        // Get Apple exercise time in minutes per day.
        appleExerciseTime = try await getHealthKitData(
            identifier: .appleExerciseTime
        ) { data in data.sumQuantity() }
        // print("appleExerciseTime = \(appleExerciseTime)")

        // Get Apple move time in calories per day.
        appleMoveTime = try await getHealthKitData(
            identifier: .appleMoveTime
        ) { data in data.sumQuantity() }
        // print("appleMoveTime = \(appleMoveTime)")

        // Get Apple stand time in minutes per day.
        appleStandTime = try await getHealthKitData(
            identifier: .appleStandTime
        ) { data in data.sumQuantity() }
        // print("appleStandTime = \(appleStandTime)")

        // Get basal energy burned in calories per day.
        // This is reported as "Resting Energy" in the Apple Health app.
        basalEnergyBurned = try await getHealthKitData(
            identifier: .basalEnergyBurned,
            frequency: .hour
        ) { data in data.sumQuantity() }
        // print("basalEnergyBurned = \(basalEnergyBurned)")

        // Get one average body mass value per day.
        // This is reported as "Weight" in the Apple Health app.
        // try await loadBodyMass()
        bodyMass = try await getHealthKitData(
            identifier: .bodyMass
        ) { data in data.averageQuantity() }
        // print("bodyMass = \(bodyMass)")

        // Get cycling miles per day.
        // This is reported as "Cycling Distance" in the Apple Health app.
        distanceCycling = try await getHealthKitData(
            identifier: .distanceCycling
        ) { data in data.sumQuantity() }
        // print("distanceCycling = \(distanceCycling)")

        // Get walking plus running miles per day.
        // This is reported as "Walking + Running Distance" in the Apple Health app.
        // try await loadDistanceWalkingRunning()
        distanceWalkingRunning = try await getHealthKitData(
            identifier: .distanceWalkingRunning
        ) { data in data.sumQuantity() }
        // print("distanceWalkingRunning = \(distanceWalkingRunning)")

        // Get wheelchair miles per day.
        distanceWheelchair = try await getHealthKitData(
            identifier: .distanceWheelchair
        ) { data in data.sumQuantity() }
        // print("distanceWheelchair = \(distanceWheelchair)")

        // Get environmental audio exposure in decibels per day.
        // This is reported as "Environmental Sound Levels" in the Apple Health app.
        environmentalAudioExposure = try await getHealthKitData(
            identifier: .environmentalAudioExposure
        ) { data in data.averageQuantity() }
        // print("environmentalAudioExposure = \(environmentalAudioExposure)")

        // Get flights climbed per day.
        flightsClimbed = try await getHealthKitData(
            identifier: .flightsClimbed
        ) { data in data.sumQuantity() }
        // print("flightsClimbed = \(flightsClimbed)")

        // Get the average headphone auto exposure in decibels per day.
        // This is reported as "Headphone Audio Levels" in the Apple Health app.
        // TODO: Don't we want the maximum each day? I couldn't get that to work.
        headphoneAudioExposure = try await getHealthKitData(
            identifier: .headphoneAudioExposure
        ) { data in data.averageQuantity() }
        // print("headphoneAudioExposure = \(headphoneAudioExposure)")

        // Get average heart rate each minute.
        heartRate = try await getHealthKitData(
            identifier: .heartRate,
            // frequency: .minute
            frequency: .hour
        ) { data in data.averageQuantity() }
        print("heartRate = \(heartRate)")

        // Get heart rate variability per day.
        // try await loadHeartRateVariabilitySDNN()
        heartRateVariabilitySDNN = try await getHealthKitData(
            identifier: .heartRateVariabilitySDNN
        ) { data in data.averageQuantity() }
        // print("heartRateVariabilitySDNN = \(heartRateVariabilitySDNN)")

        // Get the last 10 high heart rate events.
        highHeartRateEvents = try await getHealthKitEvents(
            identifier: .highHeartRateEvent
        )
        // print("highHeartRateEvents =", highHeartRateEvents)

        // Get the last 10 irregular heart rhythm events.
        irregularHeartRhythmEvents = try await getHealthKitEvents(
            identifier: .irregularHeartRhythmEvent
        )
        // print("irregularHeartRhythmEvents =", irregularHeartRhythmEvents)

        // Get one lean body mass value per day.
        leanBodyMass = try await getHealthKitData(
            identifier: .leanBodyMass
        ) { data in data.averageQuantity() }
        // print("leanBodyMass = \(leanBodyMass)")

        // Get the last 10 low heart rate events.
        lowHeartRateEvents = try await getHealthKitEvents(identifier: .lowHeartRateEvent)
        // print("lowHeartRateEvents =", lowHeartRateEvents)

        // Get number of times fallen per day.
        // If there are no falls, an empty array is used.
        // try await loadNumberOfTimesFallen()
        numberOfTimesFallen = try await getHealthKitData(
            identifier: .numberOfTimesFallen
            // Mark has one fall recorded in this time period.
            // startDate: Date.from(year: 2022, month: 4, day: 1),
            // endDate: Date.from(year: 2022, month: 4, day: 30)
        ) { data in data.sumQuantity() }
        // print("numberOfTimesFallen = \(numberOfTimesFallen)")

        // Get average oxygen saturation each day.
        // This is reported as "Blood Oxygen" in the Apple Health app.
        oxygenSaturation = try await getHealthKitData(
            identifier: .oxygenSaturation
        ) { data in data.averageQuantity() }
        // print("oxygenSaturation = \(oxygenSaturation)")

        // Get push count (wheelchair) per day.
        pushCount = try await getHealthKitData(
            identifier: .pushCount,
            frequency: .hour
        ) { data in data.sumQuantity() }
        // print("pushCount = \(pushCount)")

        // Get average respiratory rate (breaths per minute) each day.
        respiratoryRate = try await getHealthKitData(
            identifier: .respiratoryRate
        ) { data in data.averageQuantity() }
        // print("respiratoryRate = \(respiratoryRate)")

        // Get average resting heart rate each day.
        restingHeartRate = try await getHealthKitData(
            identifier: .restingHeartRate
        ) { data in data.averageQuantity() }
        // print("restingHeartRate = \(restingHeartRate)")

        // Get weekly six minute walking test results in meters.
        // The maximum value returned is 500.
        sixMinuteWalkTestDistance = try await getHealthKitData(
            identifier: .sixMinuteWalkTestDistance
        ) { data in data.averageQuantity() }
        // print("sixMinuteWalkTestDistance = \(sixMinuteWalkTestDistance)")

        // Get average stair ascent speed per day in feet per second.
        // This is reported as "Stair Speed: Up" in the Apple Health app.
        stairAscentSpeed = try await getHealthKitData(
            identifier: .stairAscentSpeed
        ) { data in data.averageQuantity() }
        // print("stairAscentSpeed = \(stairAscentSpeed)")

        // Get average stair descent speed per day in feet per second.
        // This is reported as "Stair Speed: Down" in the Apple Health app.
        stairDescentSpeed = try await getHealthKitData(
            identifier: .stairDescentSpeed
        ) { data in data.averageQuantity() }
        // print("stairDescentSpeed = \(stairDescentSpeed)")

        // Get step count per day.
        // This is reported as "Steps" in the Apple Health app.
        stepCount = try await getHealthKitData(
            identifier: .stepCount,
            frequency: .hour
        ) { data in data.sumQuantity() }
        // print("stepCount = \(stepCount)")

        // Get VO2 max average per day.
        vo2Max = try await getHealthKitData(
            identifier: .vo2Max
        ) { data in data.averageQuantity() }
        // print("vo2Max = \(vo2Max)")

        // Get average walking asymmetry percentage per day.
        // try await loadWalkingAsymmetryPercentage()
        walkingAsymmetryPercentage = try await getHealthKitData(
            identifier: .walkingAsymmetryPercentage
        ) { data in data.averageQuantity() }
        // print("walkingAsymmetryPercentage = \(walkingAsymmetryPercentage)")

        // Get average walking double support percentage per day.
        // This is reported as "Double Support Time" in the Apple Health app.
        walkingDoubleSupportPercentage = try await getHealthKitData(
            identifier: .walkingDoubleSupportPercentage
        ) { data in data.averageQuantity() }
        // print("walkingDoubleSupportPercentage = \(walkingDoubleSupportPercentage)")

        // Get walking heart rate average in beats per minute each day.
        walkingHeartRateAverage = try await getHealthKitData(
            identifier: .walkingHeartRateAverage
        ) { data in data.averageQuantity() }
        // print("walkingHeartRateAverage = \(walkingHeartRateAverage)")

        // Get average walking speed in miles per hour each day.
        walkingSpeed = try await getHealthKitData(
            identifier: .walkingSpeed,
            frequency: .hour
        ) { data in data.averageQuantity() }
        // Convert meters per second to miles per hour.
        // I couldn't find a way to request MPH as an HKUnit above.
        walkingSpeed = walkingSpeed.map { data in
            DatedValue(
                date: data.date,
                ms: data.ms,
                unit: Metrics.shared.map[.walkingSpeed]!.unit.unitString,
                value: data.value * 2.23694
            )
        }
        // print("walkingSpeed = \(walkingSpeed)")

        // Apple only computes one walking steadiness value (0 to 1) per week.
        // Measuring this requires the user to carry their iPhone
        // near their waist, such as in a pant pocket,
        // and walk steadily on flag ground.
        walkingSteadiness = try await getHealthKitData(
            identifier: .appleWalkingSteadiness
            // Mark has data in this range.
            // startDate: Date.from(year: 2022, month: 2, day: 1),
            // endDate: Date.from(year: 2022, month: 6, day: 30)
        ) { data in data.averageQuantity() }
        // print("walkingSteadiness = \(walkingSteadiness)")

        // Get average walking step length in inches per day.
        walkingStepLength = try await getHealthKitData(
            identifier: .walkingStepLength
        ) { data in data.averageQuantity() }
        // print("walkingStepLength = \(walkingStepLength)")
    }
}
