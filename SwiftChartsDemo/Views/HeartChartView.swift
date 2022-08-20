import Charts
import HealthKit
import SwiftUI

struct HeartChartView: View {
    // MARK: - State

    @State private var data: [DatedValue] = []
    @State private var dateToValueMap: [String: Double] = [:]

    @State private var chartSize: CGSize = .zero
    @State private var frequency: String = "Day"
    @State private var interpolation: String = "monotone"
    @State private var metric = Metrics.shared.map[.heartRate]!
    @State private var selectedDate = ""
    @State private var selectedValue = 0.0
    @State private var selectedX = 0.0
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

    private let interpolationMap: [String: InterpolationMethod] = [
        "monotone": .monotone,
        "cardinal": .cardinal,
        "catmullRom": .catmullRom // formulated by Edwin Catmull and Raphael Rom
    ]

    // MARK: - Properties

    private var changed: Bool {
        metric != lastMetric ||
        frequency != lastFrequency ||
        timespan != lastTimespan
    }

    /* Couldn't get this to compile. */
    private func lineMark(
        datedValue: DatedValue,
        showSymbols: Bool
    ) -> any ChartContent {
        let date = datedValue.date
        var mark: any ChartContent = LineMark(
            x: .value("Date", date),
            y: .value("Value", datedValue.value)
        )
        if showSymbols {
            mark = mark.symbol(by: .value("Date", date))
        }
        // Smooth the line.
        return mark.interpolationMethod(interpolationMap[interpolation]!)
    }

    private var chart: some View {
        GeometryReader(content: makeChart)
    }

    private var hoverRow: some View {
        let height = 40.0
        return HStack(spacing: 0) {
            VStack {
                Text(selectedDate)
                // Text("x = \(selectedX)")
                Text(selectedDate.isEmpty ? "" :
                        String(format: "%.2f", selectedValue))
            }
            .frame(height: height)
            .border(selectedDate.isEmpty ? .clear : .red)
            .position(x: max(47, 47 + max(0, selectedX - 70)), y: height - 12)
        }
        .fullWidth()
        .frame(height: height)
    }

    private var maxValue: Double {
        let item = data.max { a, b in a.value < b.value }
        return item?.value ?? 0.0
    }

    private var minValue: Double {
        let item = data.min { a, b in a.value < b.value }
        return item?.value ?? 0.0
    }

    private var path: some View {
        Path() { path in
            let x = selectedX - 20
            path.move(to: CGPoint(x: x, y: 0.0))
            path.addLine(
                to: CGPoint(x: x, y: chartSize.height)
            )
        }
        .stroke(.red, lineWidth: 1)
    }

    private var startDate: Date {
        let today = Date().withoutTime
        return timespan == "1 Day" ? today.yesterday :
            timespan == "1 Week" ? today.daysAgo(7) :
            timespan == "1 Month" ? today.monthsAgo(1) :
            today
    }

    private var title: String {
        var text = metric.identifier.rawValue

        // Remove prefix.
        let prefix = "HKQuantityTypeIdentifier"
        if text.starts(with: prefix) {
            text = text[prefix.count...]
        }

        // Add a space before all uppercase characters except the first.
        var result = text[0]
        for char in text.dropFirst() {
            if char.isUppercase {
                result += " "
            }
            result.append(char)
        }

        return result
    }

    var body: some View {
        if changed { loadData() }
        return VStack {
            HStack {
                Text("Metric").fontWeight(.bold)
                Picker("", selection: $metric) {
                    ForEach(Metrics.shared.sorted) {
                        Text($0.name).tag($0)
                    }
                }
                Spacer()
            }
            picker(
                label: "Span",
                values: ["1 Day", "1 Week", "1 Month"],
                selected: $timespan
            )
            picker(
                label: "Frequency",
                values: ["Minute", "Hour", "Day"],
                selected: $frequency
            )
            picker(
                label: "Interpolation",
                values: Array(interpolationMap.keys),
                selected: $interpolation
            )

            Text(title).fontWeight(.bold)

            // Text("values go from \(minValue) to \(maxValue)")

            hoverRow

            ZStack {
                chart
                if !selectedDate.isEmpty { path }
            }
        }
        .padding()
        .task {
            await HealthKitViewModel.shared.requestPermission()
        }
    }

    // MARK: - Methods

    private func loadData() {
        Task {
            do {
                data = try await vm.getHealthKitData(
                    identifier: metric.identifier,
                    startDate: startDate,
                    frequency: frequencyMap[frequency]!
                ) { data in
                    metric.option == .cumulativeSum ?
                        data.sumQuantity() :
                        data.averageQuantity()
                }

                dateToValueMap = [:]
                for item in data {
                    dateToValueMap[item.date] = item.value
                }

                lastMetric = metric
                lastTimespan = timespan
                lastFrequency = frequency
            } catch {
                print("error getting health data:", error)
            }
        }
    }

    private func makeChart(_ geometry: GeometryProxy) -> some View {
        DispatchQueue.main.async {
            chartSize = geometry.size
        }

        return Chart(data) { datedValue in
            LineMark(
                x: .value("Date", datedValue.date),
                y: .value("Value", datedValue.value)
            )
            // Smooth the line.
            .interpolationMethod(interpolationMap[interpolation]!)
            .symbol(by: .value("Date", datedValue.date))
        }
        .chartLegend(.hidden)
        // Support tapping on the plot area to see data point details.
        .chartOverlay { proxy in touchableOverlay(proxy: proxy) }
        // Hide the x-axis and its labels.
        // TODO: Can you only hide the labels?
        .chartXAxis(.hidden)
        // Change the y-axis to begin an minValue and end at maxValue.
        .chartYScale(domain: minValue ... maxValue)
        // Give the plot area a background color.
        .chartPlotStyle { content in
            content.background(Color(.secondarySystemBackground))
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

    private func touchableOverlay(proxy: ChartProxy) -> some View {
        GeometryReader { nthItem in

            // Taps are not registered without using .contentShape.
            Rectangle().fill(.clear).contentShape(Rectangle())
                .onDrag(
                    onEnter: { point in
                        let x = point.x - nthItem[proxy.plotAreaFrame].origin.x - 30
                        let date: String? = proxy.value(atX: x)
                        if let date {
                            selectedDate = date
                            selectedValue = dateToValueMap[date] ?? 0.0
                            selectedX = point.x
                        }
                    },
                    onExit: { selectedDate = "" }
                )
        }
    }
}
