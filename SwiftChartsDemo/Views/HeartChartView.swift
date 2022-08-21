import Charts
import HealthKit
import SwiftUI

// Much of this code was inspired by the Kavsoft YouTube video at
// https://www.youtube.com/watch?v=xS-fGYDD0qk.
struct HeartChartView: View {
    // MARK: - State

    @State private var chartType = "Line"
    @State private var data: [DatedValue] = []
    @State private var dateToValueMap: [String: Double] = [:]
    @State private var frequency: Frequency = .day
    @State private var metric = Metrics.shared.map[.heartRate]!
    @State private var selectedDate = ""
    @State private var selectedValue = 0.0
    @State private var timeSpan = "1 Week"

    @StateObject var vm = HealthKitViewModel.shared

    // MARK: - Constants

    // This is used to smooth line charts.
    // The options are .monotone, .cardinal, and
    // .catmullRom (formulated by Edwin Catmull and Raphael Rom).
    let interpolationMethod: InterpolationMethod = .catmullRom

    // MARK: - Properties

    private var annotation: some View {
        VStack {
            Text(selectedDate)
            Text(String(format: "%0.2f", selectedValue))
        }
        .padding(5)
        .background {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(.white.shadow(.drop(radius: 3)))
        }
    }

    private var chart: some View {
        Chart(data) { datedValue in
            // TODO: Select number of decimal places to display based on metric.
            let value = datedValue.animate ? datedValue.value : 0
            if chartType == "Bar" {
                BarMark(
                    x: .value("Date", datedValue.date),
                    y: .value("Value", value)
                )
                .foregroundStyle(.blue.gradient)
            } else {
                LineMark(
                    x: .value("Date", datedValue.date),
                    y: .value("Value", value)
                )
                .interpolationMethod(interpolationMethod)
                .symbol(by: .value("Date", datedValue.date))

                AreaMark(
                    x: .value("Date", datedValue.date),
                    y: .value("Value", value)
                )
                .foregroundStyle(.blue.opacity(0.2))
                .interpolationMethod(interpolationMethod)
            }

            if datedValue.date == selectedDate {
                RuleMark(x: .value("Date", selectedDate))
                    .annotation(position: .top) { annotation }
                    .foregroundStyle(.red)
                    .lineStyle(.init(lineWidth: 1, dash: [10], dashPhase: 5))
            }
        }
        .onAppear { animateGraph() }

        .chartLegend(.hidden)

        // Support tapping on the plot area to see data point details.
        .chartOverlay { proxy in chartOverlay(proxy: proxy) }

        // Hide the x-axis and its labels.
        // TODO: Can you only hide the labels?
        .chartXAxis(.hidden)

        // Change the y-axis to begin an minValue and end at maxValue.
        // TODO: This breaks the ability to set the chart height below.
        // .chartYScale(domain: minValue ... maxValue)

        // Give the plot area a background color.
        .chartPlotStyle { content in
            content.background(Color(.secondarySystemBackground))
        }

        .frame(height: 400)
        .padding(.leading, 20) // leaves room to left for RuleMark annotation
        .padding(.top, 50) // leaves room above for RuleMark annotation
    }

    private var chartTypePicker: some View {
        picker(
            label: "Chart Type",
            values: ["Bar", "Line"],
            selected: $chartType
        )
        .onChange(of: chartType) { _ in
            // Make a copy of data where animate is false in each item.
            // This allows the new chart to be animated.
            data = data.map { item in
                DatedValue(
                    date: item.date,
                    ms: item.ms,
                    unit: item.unit,
                    value: item.value
                )
            }

            animateGraph()
        }
    }

    private var maxValue: Double {
        let item = data.max { a, b in a.value < b.value }
        return item?.value ?? 0.0
    }

    private var metricPicker: some View {
        HStack {
            Text("Metric").fontWeight(.bold)
            Picker("", selection: $metric) {
                ForEach(Metrics.shared.sorted) {
                    Text($0.name).tag($0)
                }
            }
            Spacer()
        }
        .onChange(of: metric) { _ in loadData() }
    }

    private var minValue: Double {
        let item = data.min { a, b in a.value < b.value }
        return item?.value ?? 0.0
    }

    private var startDate: Date {
        let today = Date().withoutTime
        return timeSpan == "1 Day" ? today.yesterday :
            timeSpan == "1 Week" ? today.daysAgo(7) :
            timeSpan == "1 Month" ? today.monthsAgo(1) :
            today
    }

    private var timeSpanPicker: some View {
        // TODO: No chart will render if "1 Day" is selected
        // TODO: and we do not have hourly data for selected metric.
        // TODO: In that case either don't allow selecting "1 Day"
        // TODO: OR gather hourly data for all metrics.
        picker(
            label: "Time Span",
            values: ["1 Day", "1 Week", "1 Month"],
            selected: $timeSpan
        )
        .onChange(of: timeSpan) { _ in
            switch timeSpan {
            case "1 Day":
                frequency = .hour
            case "1 Week":
                frequency = .day
            case "1 Month":
                frequency = .day
            default:
                break
            }

            loadData()
        }
    }

    private var title: String {
        var text = metric.identifier.rawValue

        // Remove metric prefix.
        let prefix = "HKQuantityTypeIdentifier"
        if text.starts(with: prefix) {
            text = text[prefix.count...]
        }

        // Add a space before all uppercase characters except the first.
        var result = text[0]
        for char in text.dropFirst() {
            if char.isUppercase { result += " " }
            result.append(char)
        }

        return result
    }

    var body: some View {
        VStack {
            metricPicker
            timeSpanPicker
            chartTypePicker
            Text(title).fontWeight(.bold)
            // Text("values go from \(minValue) to \(maxValue)")
            chart
            Spacer()
        }
        .onAppear(perform: loadData)
        .padding()
        .task {
            await HealthKitViewModel.shared.requestPermission()
        }
    }

    // MARK: - Methods

    private func animateGraph() {
        for (index, _) in data.enumerated() {
            // Delay rendering each data point a bit longer than the previous one.
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Double(index) * 0.015
            ) {
                let spring = 0.5
                withAnimation(.interactiveSpring(
                    response: spring,
                    dampingFraction: spring,
                    blendDuration: spring
                )) {
                    data[index].animate = true
                }
            }
        }
    }

    private func chartOverlay(proxy: ChartProxy) -> some View {
        GeometryReader { innerProxy in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let location = value.location
                            if let date: String = proxy.value(atX: location.x) {
                                selectedDate = date
                                selectedValue = dateToValueMap[date] ?? 0.0
                            }
                        }
                        .onEnded { _ in selectedDate = "" }
                )
        }
    }

    private func loadData() {
        Task {
            do {
                data = try await vm.getHealthKitData(
                    identifier: metric.identifier,
                    startDate: startDate,
                    frequency: frequency
                ) { data in
                    metric.option == .cumulativeSum ?
                        data.sumQuantity() :
                        data.averageQuantity()
                }
                // All objects in data will now have animate set to false.

                dateToValueMap = [:]
                for item in data {
                    dateToValueMap[item.date] = item.value
                }

                animateGraph()
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
