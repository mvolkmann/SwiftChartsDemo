import HealthKit

// swiftlint:disable type_body_length
class HealthStore {
    // This assumes that HKHealthStore.isHealthDataAvailable()
    // has already been checked.
    private var store = HKHealthStore()

    private func categoryType(
        _ typeId: HKCategoryTypeIdentifier
    ) -> HKCategoryType {
        HKCategoryType.categoryType(forIdentifier: typeId)!
    }

    private func characteristicType(
        _ typeId: HKCharacteristicTypeIdentifier
    ) -> HKCharacteristicType {
        HKCharacteristicType.characteristicType(forIdentifier: typeId)!
    }

    private func dateRangePredicate(
        startDate: Date,
        endDate: Date?
    ) -> NSPredicate {
        HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
    }

    // Gets specific data from HealthKit.
    // swiftlint:disable function_body_length
    func getData(
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
            frequencyToUse == .day ? DateComponents(day: 1) :
            frequencyToUse == .week ? DateComponents(day: 7) :
            DateComponents(day: 1)

        let collection = try await queryQuantityCollection(
            typeId: metric.identifier,
            options: metric.option,
            startDate: startDate,
            endDate: endDate,
            interval: interval
        )

        var datedValues = collection.map { data -> DatedValue in
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

        if !datedValues.isEmpty,
           HealthKitViewModel.addZeros.contains(identifier) {
            for index in 0 ..< datedValues.count - 1 {
                let current = datedValues[index]
                let next = datedValues[index + 1]
                let currentDate = Date.from(ms: current.ms)
                let nextDate = Date.from(ms: next.ms)

                if frequency == .hour {
                    let missing = currentDate.hoursBetween(date: nextDate) - 1
                    if missing > 0 {
                        for delta in 1 ... missing {
                            let date = currentDate.hoursAfter(delta)
                            let datedValue = DatedValue(
                                date: date.ymdh,
                                ms: date.milliseconds,
                                unit: current.unit,
                                value: 0.0
                            )
                            datedValues.insert(datedValue, at: index + delta)
                        }
                    }
                } else if frequency == .day {
                    let missing = currentDate.daysBetween(date: nextDate) - 1
                    if missing > 0 {
                        for delta in 1 ... missing {
                            let date = currentDate.daysAfter(delta)
                            let datedValue = DatedValue(
                                date: date.ymd,
                                ms: date.milliseconds,
                                unit: current.unit,
                                value: 0.0
                            )
                            datedValues.insert(datedValue, at: index + delta)
                        }
                    }
                }
            }
        }

        return datedValues
    }

    private func quantityType(
        _ typeId: HKQuantityTypeIdentifier
    ) -> HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: typeId)!
    }

    // enum with values notSet(0), female(1), male(2), and other(3)
    func biologicalSex() throws -> HKBiologicalSex {
        try store.biologicalSex().biologicalSex
    }

    // enum with values notSet(0), aPositive, aNegative, bPositive, bNegative,
    // abPositive, abNegative, oPositive, and oNegative
    func bloodType() throws -> HKBloodType {
        try store.bloodType().bloodType
    }

    func dateOfBirth() throws -> DateComponents? {
        var dateOfBirth: DateComponents?
        do {
            dateOfBirth = try store.dateOfBirthComponents()
        } catch {
            print("HealthKitViewModel.dateOfBirth: can't get birthdate")
        }
        return dateOfBirth
    }

    // enum with values notSet(0), I, II, III, IV, V, and VI
    func fitzpatrickSkinType() throws -> HKFitzpatrickSkinType {
        try store.fitzpatrickSkinType().skinType
    }

    // Gets height in inches.
    func height() async throws -> Double {
        let sampleType = HKSampleType.quantityType(
            forIdentifier: HKQuantityTypeIdentifier.height
        )!

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: nil,
                limit: 1,
                sortDescriptors: nil
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result = results?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }

                let height = result.quantity.doubleValue(for: .inch())
                continuation.resume(returning: height)
            }
            store.execute(query)
        }
    }

    func queryQuantityCollection(
        typeId: HKQuantityTypeIdentifier,
        options: HKStatisticsOptions,
        startDate: Date? = nil,
        endDate: Date? = nil,
        interval: DateComponents? = nil
    ) async throws -> [HKStatistics] {
        // Default end date is today.
        let end = endDate ?? Date()

        // Default start date is seven days before the end date.
        let start = startDate ?? end.daysBefore(7)

        // Default interval is one day.
        let intervalComponents = interval ?? DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType(typeId),
            quantitySamplePredicate: dateRangePredicate(
                startDate: start,
                endDate: end
            ),
            options: options,
            anchorDate: Date.mondayAt12AM(), // defined in DateExtensions.swift
            intervalComponents: intervalComponents
        )
        return try await withCheckedThrowingContinuation { continuation in
            query.initialResultsHandler = { _, collection, error in
                if let error = error {
                    print("HealthStore.queryQuantityCollection: error =", error)
                    if error.localizedDescription == "Authorization not determined" {
                        Task { await self.requestPermission() }
                    } else {
                        handleError(
                            "HealthStore.queryQuantityCollection",
                            error
                        )
                    }
                    continuation.resume(throwing: error)
                } else if let collection = collection {
                    let statistics = collection.statistics()
                    if statistics.count == 0 {
                        Task { await self.requestPermission() }
                    }
                    continuation.resume(returning: statistics)
                } else {
                    print("HealthStore.queryQuantityCollection: no data found")
                    continuation.resume(returning: [HKStatistics]())
                }
            }
            store.execute(query)
        }
    }

    // swiftlint:disable function_body_length
    func requestAuthorization() async throws {
        // This throws if authorization could not be requested.
        // Not throwing is not an indication that the user
        // granted all the requested permissions.
        try await store.requestAuthorization(
            // The app can update these.
            toShare: [],
            // The app can read these.
            read: [
                .activitySummaryType(),
                .workoutType(),

                // It seems there is both appleStandHour and appleStandHours.
                // Are these just two names for the same thing?
                categoryType(.appleStandHour),
                categoryType(.handwashingEvent),
                categoryType(.sleepAnalysis),
                categoryType(.toothbrushingEvent),

                characteristicType(.activityMoveMode),
                characteristicType(.biologicalSex),
                characteristicType(.bloodType),
                characteristicType(.dateOfBirth),
                characteristicType(.fitzpatrickSkinType),
                characteristicType(.wheelchairUse),

                quantityType(.activeEnergyBurned),
                quantityType(.appleExerciseTime),
                quantityType(.appleStandTime),
                quantityType(.appleWalkingSteadiness),
                quantityType(.basalEnergyBurned),

                // This data must be supplied by a device like a Withings scale.
                quantityType(.bodyFatPercentage),
                quantityType(.bodyMass),
                quantityType(.bodyMassIndex),
                quantityType(.leanBodyMass),

                quantityType(.distanceCycling),
                // quantityType(.distanceDownhillSnowSports),
                // quantityType(.distanceSwimming),
                quantityType(.distanceWalkingRunning),

                // Not getting data due to not using wheelchair
                // and not enabling wheelchair mode.
                quantityType(.distanceWheelchair),

                // Not getting data.  Maybe Apple Watch can't measure this.
                quantityType(.electrodermalActivity),

                quantityType(.environmentalAudioExposure),

                quantityType(.flightsClimbed),
                quantityType(.headphoneAudioExposure),
                quantityType(.heartRate),

                // Values are in milliseconds.
                // Normal values are between 20 and 200 ms.
                quantityType(.heartRateVariabilitySDNN),

                // Requires manual data entry in Health app.
                quantityType(.height),

                categoryType(.highHeartRateEvent),
                categoryType(.irregularHeartRhythmEvent),
                categoryType(.lowHeartRateEvent),

                // Not getting data for this.
                // What is required to get this data?
                quantityType(.nikeFuel),

                // I verified this with one fall on 4/3/22 that was
                // triggered by catching a ball that was thrown hard.
                quantityType(.numberOfTimesFallen),

                // Values are between 0 and 1.
                // Values between 0.95 and 1.0 are normal.
                quantityType(.oxygenSaturation),

                // Not getting data due to not using wheelchair
                // and not enabling wheelchair mode.
                quantityType(.pushCount),

                // This is breaths per day.
                quantityType(.respiratoryRate),

                // This only provides one number per day.
                quantityType(.restingHeartRate),

                // One result per week is computed.
                // The maximum value is 500m.
                quantityType(.sixMinuteWalkTestDistance),

                quantityType(.stairAscentSpeed),
                quantityType(.stairDescentSpeed),
                quantityType(.stepCount),

                // I don't get any data because I haven't been swimming.
                quantityType(.swimmingStrokeCount),

                // It seems we cannot get uvExposure from a watch or phone.
                quantityType(.uvExposure),

                // In the Health app, this appears under "Cardio Fitness".
                quantityType(.vo2Max),

                // Requires manual data entry.
                quantityType(.waistCircumference),

                quantityType(.walkingAsymmetryPercentage),
                quantityType(.walkingDoubleSupportPercentage),
                quantityType(.walkingHeartRateAverage),
                quantityType(.walkingSpeed),
                quantityType(.walkingStepLength)
            ]
        )
    }

    func requestPermission() async {
        do {
            // Request permission from the user to access HealthKit data.
            // If they have already granted permission,
            // they will not be prompted again.
            print("HealthStore.requestPermission: starting")
            try await requestAuthorization()
            print("HealthStore.requestPermission: finished")
        } catch {
            handleError("HealthStore.requestPermission", error)
        }
    }

    // enum with values notSet(0), no(1), and yes(2)
    func wheelchairUse() throws -> HKWheelchairUse {
        try store.wheelchairUse().wheelchairUse
    }
}
