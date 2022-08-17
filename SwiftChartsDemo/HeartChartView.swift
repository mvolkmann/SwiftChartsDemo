import Charts
import HealthKit
import SwiftUI

struct HeartChartView: View {
    // MARK: - State

    @State private var data: [DatedValue] = []

    @State private var frequency: String = "Day"
    @State private var metric = Metrics.shared.map[.heartRate]!
    @State private var timespan: String = "1 Week"

    @State private var lastFrequency: String = ""
    @State private var lastMetric = Metrics.shared.map[.appleWalkingSteadiness]!
    @State private var lastTimespan: String = ""

    @StateObject var vm = HealthKitViewModel.shared

    // MARK: - Constants

    private let frequencyMap: [String: Frequency] = [
        "Minute": .minute,
        "Hour": .hour,
        "Day": .day
    ]

    // MARK: - Properties

    private var changed: Bool {
        metric != lastMetric ||
        frequency != lastFrequency ||
        timespan != lastTimespan
    }

    private var startDate: Date {
        let today = Date().withoutTime
        return timespan == "1 Day" ? today.yesterday :
            timespan == "1 Week" ? today.daysAgo(7) :
            timespan == "1 Month" ? today.monthsAgo(1) :
            timespan == "3 Month" ? today.monthsAgo(3) :
            today
    }

    var body: some View {
        if changed { loadData() }
        return VStack {
            Text("Heart Rate (\(vm.heartRate.count))")
                .fontWeight(.bold)
            picker(
                label: "Span",
                values: ["1 Day", "1 Week", "1 Month", "3 Months"],
                selected: $timespan
            )
            picker(
                label: "Frequency",
                values: ["Minute", "Hour", "Day"],
                selected: $frequency
            )
            HStack {
                Text("Metric").fontWeight(.bold)
                Picker("", selection: $metric) {
                    ForEach(Metrics.shared.sorted) {
                        Text($0.name).tag($0)
                    }
                }
                Spacer()
            }
            //Chart(vm.heartRate) { heart in
            Chart(data) { heart in
                LineMark(
                    x: .value("Date", heart.date),
                    y: .value("BPM", heart.value)
                )
            }
        }
        .padding()
        .task {
            await HealthKitViewModel.shared.load()
        }
    }

    // MARK: - Methods

    private func loadData() {
        print("loadData entered")
        Task {
            do {
                data = try await vm.getHealthKitData(
                    identifier: metric.identifier,
                    startDate: startDate,
                    frequency: frequencyMap[frequency]
                ) { data in
                    metric.option == .cumulativeSum ?
                        data.sumQuantity() :
                        data.averageQuantity()
                }
                lastMetric = metric
                lastTimespan = timespan
                lastFrequency = frequency
            } catch {
                print("error getting health data:", error)
            }
        }
    }

    private func picker(
        label: String,
        values: [String],
        selected: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).fontWeight(.bold)
            Picker("", selection: selected) {
                ForEach(values, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct HeartChartView_Previews: PreviewProvider {
    static var previews: some View {
        HeartChartView()
    }
}
