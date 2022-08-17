import HealthKit

enum Frequency {
    case minute, hour, day
}

struct Metric: Hashable, Identifiable {
    let name: String
    let identifier: HKQuantityTypeIdentifier
    let unit: HKUnit
    let option: HKStatisticsOptions
    let frequency: Frequency
    let lowerIsBetter: Bool

    var id = UUID()

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

class Metrics {
    static let shared = Metrics()

    var map: [HKQuantityTypeIdentifier: Metric] = [:]

    var sorted: [Metric] {
        map.values.sorted { $0.name < $1.name }
    }

    // This class is a singleton.
    // swiftlint:disable function_body_length
    private init() {
        addMetricSum(
            name: "Active Energy Burned (calories)",
            identifier: .activeEnergyBurned,
            unit: .largeCalorie(),
            frequency: .hour
        )
        addMetricSum(
            name: "Exercise Time (minutes)",
            identifier: .appleExerciseTime,
            unit: .minute()
        )
        addMetricSum(
            name: "Move Time (calories)",
            identifier: .appleMoveTime,
            unit: .largeCalorie()
        )
        addMetricSum(
            name: "Stand Time (minutes)",
            identifier: .appleStandTime,
            unit: .minute()
        )
        addMetricAverage(
            name: "Walking Steadiness %",
            identifier: .appleWalkingSteadiness,
            unit: .percent()
        )
        addMetricSum(
            name: "Resting Energy Burned (calories)",
            identifier: .basalEnergyBurned,
            unit: .largeCalorie(),
            frequency: .hour
        )
        addMetricAverage(
            name: "Body Fat %",
            identifier: .bodyFatPercentage,
            unit: .percent(),
            lowerIsBetter: true
        )
        addMetricAverage(
            name: "Weight (pounds)",
            identifier: .bodyMass,
            unit: .pound(),
            lowerIsBetter: true
        )
        addMetricAverage(
            name: "Body Mass Index (BMI)",
            identifier: .bodyMassIndex,
            unit: .count(),
            lowerIsBetter: true
        )
        addMetricSum(
            name: "Distance Cycling (miles)",
            identifier: .distanceCycling,
            unit: .mile()
        )
        addMetricSum(
            name: "Distance Walking & Running (miles)",
            identifier: .distanceWalkingRunning,
            unit: .mile()
        )
        addMetricSum(
            name: "Distance Wheelchair (miles)",
            identifier: .distanceWheelchair,
            unit: .mile()
        )
        addMetricAverage(
            name: "Environmental Audio Exposure",
            identifier: .environmentalAudioExposure,
            unit: HKUnit(from: "dBASPL"),
            lowerIsBetter: true
        )
        addMetricSum(
            name: "Flights Climbed",
            identifier: .flightsClimbed,
            unit: .count()
        )
        addMetricAverage(
            name: "Headphone Audio Exposure",
            identifier: .headphoneAudioExposure,
            unit: HKUnit(from: "dBASPL"),
            lowerIsBetter: true
        )
        addMetricAverage(
            name: "Heart Rate (BPM)",
            identifier: .heartRate,
            unit: HKUnit(from: "count/min"),
            frequency: .minute,
            lowerIsBetter: true
        )
        addMetricAverage(
            name: "Heart Rate Variability",
            identifier: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            lowerIsBetter: true
        )
        addMetricAverage(
            name: "Lean Body Mass (pounds)",
            identifier: .leanBodyMass,
            unit: .pound(),
            lowerIsBetter: true
        )
        addMetricSum(
            name: "Number of Times Fallen",
            identifier: .numberOfTimesFallen,
            unit: .count(),
            lowerIsBetter: true
        )
        addMetricAverage(
            name: "Oxygen Saturation %",
            identifier: .oxygenSaturation,
            unit: .percent()
        )
        addMetricSum(
            name: "Wheelchair Push Count",
            identifier: .pushCount,
            unit: .count(),
            frequency: .hour
        )
        addMetricAverage(
            name: "Respiratory Rate (breaths per minute)",
            identifier: .respiratoryRate,
            unit: HKUnit(from: "count/min"),
            lowerIsBetter: true
        )
        addMetricAverage(
            name: "Resting Heart Rate (BPM)",
            identifier: .restingHeartRate,
            unit: HKUnit(from: "count/min"),
            lowerIsBetter: true
        )
        addMetricAverage(
            name: "Six Minute Walk Test Distance (meters)",
            identifier: .sixMinuteWalkTestDistance,
            unit: .meter()
        )
        addMetricAverage(
            name: "Stair Ascent Speed (feet per second)",
            identifier: .stairAscentSpeed,
            unit: HKUnit(from: "ft/s")
        )
        addMetricAverage(
            name: "Stair Descent Speed (feet per second)",
            identifier: .stairDescentSpeed,
            unit: HKUnit(from: "ft/s")
        )
        addMetricSum(
            name: "Step Count",
            identifier: .stepCount,
            unit: .count(),
            frequency: .hour
        )

        let mL = HKUnit.literUnit(with: .milli)
        let kgMin = HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute())
        // This is reported as "Cardio Fitness" in the Apple Health app.
        addMetricAverage(
            name: "VO2 Max",
            identifier: .vo2Max,
            unit: mL.unitDivided(by: kgMin)
        )

        addMetricAverage(
            name: "Walking Asymmetry %",
            identifier: .walkingAsymmetryPercentage,
            unit: .percent(),
            lowerIsBetter: true
        )
        addMetricAverage(
            name: "Walking Double Support %",
            identifier: .walkingDoubleSupportPercentage,
            unit: .percent(),
            lowerIsBetter: true
        )
        addMetricAverage(
            name: "Walking Heart Rate (BPM)",
            identifier: .walkingHeartRateAverage,
            unit: HKUnit(from: "count/min"),
            lowerIsBetter: true
        )
        addMetricAverage(
            name: "Walking Speed (meters per second)",
            identifier: .walkingSpeed,
            unit: HKUnit(from: "m/s"), // meters per second
            frequency: .hour
        )
        addMetricAverage(
            name: "Walking Step Length (inches)",
            identifier: .walkingStepLength,
            unit: .inch()
        )
    }

    private func addMetricAverage(
        name: String,
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        frequency: Frequency = .day,
        lowerIsBetter: Bool = false
    ) {
        map[identifier] = Metric(
            name: name,
            identifier: identifier,
            unit: unit,
            option: .discreteAverage,
            frequency: frequency,
            lowerIsBetter: lowerIsBetter
        )
    }

    private func addMetricSum(
        name: String,
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        frequency: Frequency = .day,
        lowerIsBetter: Bool = false
    ) {
        map[identifier] = Metric(
            name: name,
            identifier: identifier,
            unit: unit,
            option: .cumulativeSum,
            frequency: frequency,
            lowerIsBetter: lowerIsBetter
        )
    }
}
