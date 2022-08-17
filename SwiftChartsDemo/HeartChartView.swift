import Charts
import HealthKit
import SwiftUI

struct HeartChartView: View {
    @State private var frequency: String = "Day"
    @State private var identifier: HKQuantityTypeIdentifier = .heartRate
    @State private var timespan: String = "1 Week"
    @StateObject var vm = HealthKitViewModel.shared

    var body: some View {
        VStack {
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
                Picker("", selection: $identifier) {
                    ForEach(Metrics.shared.sorted) {
                        Text($0.name).tag($0.identifier)
                    }
                }
                Spacer()
            }
            Chart(vm.heartRate) { heart in
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
