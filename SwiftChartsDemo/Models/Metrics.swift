import HealthKit

enum Frequency {
    case minute, hour, day
}

struct Metric {
    let identifier: HKQuantityTypeIdentifier
    let unit: HKUnit
    let option: HKStatisticsOptions
    let frequency: Frequency
    let lowerIsBetter: Bool
}

class Metrics {
    var map: [HKQuantityTypeIdentifier: Metric] = [:]

    static let shared = Metrics()

    // This class is a singleton.
    // swiftlint:disable function_body_length
    private init() {
        addMetricSum(
            identifier: .activeEnergyBurned,
            unit: .largeCalorie(),
            frequency: .hour
        )
        addMetricSum(
            identifier: .appleExerciseTime,
            unit: .minute()
        )
        addMetricSum(
            identifier: .appleMoveTime,
            unit: .largeCalorie()
        )
        addMetricSum(
            identifier: .appleStandTime,
            unit: .minute()
        )
        addMetricAverage(
            identifier: .appleWalkingSteadiness,
            unit: .percent()
        )
        addMetricSum(
            identifier: .basalEnergyBurned,
            unit: .largeCalorie(),
            frequency: .hour
        )
        addMetricAverage(
            identifier: .bodyFatPercentage,
            unit: .percent(),
            lowerIsBetter: true
        )
        addMetricAverage(
            identifier: .bodyMass,
            unit: .pound(),
            lowerIsBetter: true
        )
        addMetricAverage(
            identifier: .bodyMassIndex,
            unit: .count(),
            lowerIsBetter: true
        )
        addMetricSum(
            identifier: .distanceCycling,
            unit: .mile()
        )
        addMetricSum(
            identifier: .distanceWalkingRunning,
            unit: .mile()
        )
        addMetricSum(
            identifier: .distanceWheelchair,
            unit: .mile()
        )
        addMetricAverage(
            identifier: .environmentalAudioExposure,
            unit: HKUnit(from: "dBASPL"),
            lowerIsBetter: true
        )
        addMetricSum(
            identifier: .flightsClimbed,
            unit: .count()
        )
        addMetricAverage(
            identifier: .headphoneAudioExposure,
            unit: HKUnit(from: "dBASPL"),
            lowerIsBetter: true
        )
        addMetricAverage(
            identifier: .heartRate,
            unit: HKUnit(from: "count/min"),
            frequency: .minute,
            lowerIsBetter: true
        )
        addMetricAverage(
            identifier: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            lowerIsBetter: true
        )
        addMetricAverage(
            identifier: .leanBodyMass,
            unit: .pound(),
            lowerIsBetter: true
        )
        addMetricSum(
            identifier: .numberOfTimesFallen,
            unit: .count(),
            lowerIsBetter: true
        )
        addMetricAverage(
            identifier: .oxygenSaturation,
            unit: .percent()
        )
        addMetricSum(
            identifier: .pushCount,
            unit: .count(),
            frequency: .hour
        )
        addMetricAverage(
            identifier: .respiratoryRate,
            unit: HKUnit(from: "count/min"),
            lowerIsBetter: true
        )
        addMetricAverage(
            identifier: .restingHeartRate,
            unit: HKUnit(from: "count/min"),
            lowerIsBetter: true
        )
        addMetricAverage(
            identifier: .sixMinuteWalkTestDistance,
            unit: .meter()
        )
        addMetricAverage(
            identifier: .stairAscentSpeed,
            unit: HKUnit(from: "ft/s")
        )
        addMetricAverage(
            identifier: .stairDescentSpeed,
            unit: HKUnit(from: "ft/s")
        )
        addMetricSum(
            identifier: .stepCount,
            unit: .count(),
            frequency: .hour
        )

        let mL = HKUnit.literUnit(with: .milli)
        let kgMin = HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute())
        // This is reported as "Cardio Fitness" in the Apple Health app.
        addMetricAverage(
            identifier: .vo2Max,
            unit: mL.unitDivided(by: kgMin)
        )

        addMetricAverage(
            identifier: .walkingAsymmetryPercentage,
            unit: .percent(),
            lowerIsBetter: true
        )
        addMetricAverage(
            identifier: .walkingDoubleSupportPercentage,
            unit: .percent(),
            lowerIsBetter: true
        )
        addMetricAverage(
            identifier: .walkingHeartRateAverage,
            unit: HKUnit(from: "count/min"),
            lowerIsBetter: true
        )
        addMetricAverage(
            identifier: .walkingSpeed,
            unit: HKUnit(from: "m/s"), // meters per second
            frequency: .hour
        )
        addMetricAverage(
            identifier: .walkingStepLength,
            unit: .inch()
        )
    }

    private func addMetricAverage(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        frequency: Frequency = .day,
        lowerIsBetter: Bool = false
    ) {
        map[identifier] = Metric(
            identifier: identifier,
            unit: unit,
            option: .discreteAverage,
            frequency: frequency,
            lowerIsBetter: lowerIsBetter
        )
    }

    private func addMetricSum(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        frequency: Frequency = .day,
        lowerIsBetter: Bool = false
    ) {
        map[identifier] = Metric(
            identifier: identifier,
            unit: unit,
            option: .cumulativeSum,
            frequency: frequency,
            lowerIsBetter: lowerIsBetter
        )
    }
}
