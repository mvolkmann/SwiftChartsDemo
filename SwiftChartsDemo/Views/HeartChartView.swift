import Charts
import HealthKit
import SwiftUI

struct HeartChartView: View {
    // MARK: - State

    @State private var data: [DatedValue] = []
    @State private var dateToValueMap: [String: Double] = [:]

    @State private var chartType = "Line"
    @State private var frequency: Frequency = .day
    @State private var metric = Metrics.shared.map[.heartRate]!
    @State private var selectedDate = ""
    @State private var selectedValue = 0.0
    @State private var selectedX = 0.0
    @State private var timespan = "1 Week"

    @StateObject var vm = HealthKitViewModel.shared

    // MARK: - Properties

    private var chart: some View {
        Chart(data) { datedValue in
            let value = datedValue.animate ? datedValue.value : 0
            if chartType == "Bar" {
                BarMark(
                    x: .value("Date", datedValue.date),
                    y: .value("Value", value)
                )
                .foregroundStyle(.blue.gradient)
            } else {
                // lineMark(datedValue: datedValue, showSymbols: true)
                LineMark(
                    x: .value("Date", datedValue.date),
                    y: .value("Value", value)
                )
                // Smooth the line.  Options are .monotone, .cardinal, and
                // .catmullRom (formulated by Edwin Catmull and Raphael Rom)
                .interpolationMethod(.catmullRom)
                .symbol(by: .value("Date", datedValue.date))

                AreaMark(
                    x: .value("Date", datedValue.date),
                    y: .value("Value", value)
                )
                .foregroundStyle(.blue.opacity(0.2))
                .interpolationMethod(.catmullRom)
            }

            if datedValue.date == selectedDate {
                RuleMark(x: .value("Date", selectedDate))
                    .annotation(position: .top) {
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
        // This breaks the ability to set the chart height below.
        // .chartYScale(domain: minValue ... maxValue)

        // Give the plot area a background color.
        .chartPlotStyle { content in
            content.background(Color(.secondarySystemBackground))
        }

        .frame(height: 400)
        .padding(.leading, 20) // leaves room to left for RuleMark annotation
        .padding(.top, 50) // leaves room above for RuleMark annotation
    }

    private var maxValue: Double {
        let item = data.max { a, b in a.value < b.value }
        return item?.value ?? 0.0
    }

    private var minValue: Double {
        let item = data.min { a, b in a.value < b.value }
        return item?.value ?? 0.0
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
        VStack {
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
            .onChange(of: chartType) { _ in
                // Make a copy of data where animate is false in each item.
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
            .onChange(of: metric) { _ in loadData() }
            .onChange(of: timespan) { _ in
                switch timespan {
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
            picker(
                label: "Chart Type",
                values: ["Bar", "Line"],
                selected: $chartType
            )

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

    private func animateGraph(fromChange: Bool = false) {
        print("in animateGraph")
        for (index, _) in data.enumerated() {
            // Delay rendering each data point a bit longer than the previous one.
            DispatchQueue.main.asyncAfter(
                //deadline: .now() + Double(index) * (fromChange ? 0.03 : 0.05)
                deadline: .now() + Double(index) * 0.03
            ) {
                let spring = 0.8
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

                animateGraph(fromChange: true)
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
