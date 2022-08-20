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
                date: frequencyToUse == .day ? date.ymd : date.ymdh,
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

    func requestPermission() async {
        do {
            // Request permission from the user to access HealthKit data.
            // If they have already granted permission,
            // they will not be prompted again.
            try await store.requestAuthorization()
        } catch {
            handleError("HealthKitViewModel.load", error)
        }
    }
}
