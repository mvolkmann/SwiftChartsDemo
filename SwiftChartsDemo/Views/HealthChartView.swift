// import ActivityKit
import Charts
import HealthKit
import SwiftUI
import WidgetKit

// Much of this code was inspired by the Kavsoft YouTube video at
// https://www.youtube.com/watch?v=xS-fGYDD0qk.
// swiftlint:disable file_length type_body_length
struct HealthChartView: View {
    // MARK: - State

    @Environment(\.colorScheme) var colorScheme

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

    let unitMap: [HKUnit: String] = [
        .count(): "count",
        HKUnit(from: "count/min"): "beats per minute",
        HKUnit(from: "ft/s"): "feet per second",
        .hour(): "hours",
        .largeCalorie(): "calories",
        HKUnit(from: "m/s"): "meters per second",
        .inch(): "inches",
        .meter(): "meters",
        .mile(): "miles",
        HKUnit.secondUnit(with: .milli): "standard deviation in milliseconds",
        .minute(): "minutes",
        .percent(): "percentage",
        .pound(): "pounds"
    ]

    // MARK: - Properties

    private var annotation: some View {
        VStack {
            Text(dateDisplay)
            Text(formattedValue)
        }
        .padding(5)
        .background {
            let fillColor: Color = colorScheme == .light ?
                .white : Color(.secondarySystemBackground)
            let myFill = fillColor.shadow(.drop(radius: 3))
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(myFill)
        }
        .foregroundColor(Color(.label))
    }

    private var chart: some View {
        Chart {
            // Using Foreach instead of passing data to Chart above
            // so we can get the index of each item in data.
            // The index is used to determine the
            // position of the RuleMark annotation below.

            // With this version of Foreach, we get "The compiler is
            // unable to type-check this expression in a resaonable time".
            // ForEach(data.enumerated(), id: \.self) { index, datedValue in

            // This version of ForEach works.
            ForEach(data.indices, id: \.self) { index in
                let datedValue = data[index]

                let multiplier = metric.unit == .percent() ? 100.0 : 1.0
                let value = datedValue.animate ? datedValue
                    .value * multiplier : 0.0

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

                    if !canScaleYAxis(metric: metric) {
                        AreaMark(
                            x: .value("Date", datedValue.date),
                            y: .value("Value", value)
                        )
                        .foregroundStyle(.blue.opacity(0.2))
                        .interpolationMethod(interpolationMethod)
                    }
                }

                if datedValue.date == selectedDate {
                    RuleMark(x: .value("Date", selectedDate))
                        .annotation(position: annotationPosition(index)) {
                            annotation
                        }
                        .foregroundStyle(.red)
                        .lineStyle(.init(
                            lineWidth: 1,
                            dash: [10],
                            dashPhase: 5
                        ))
                }
            }
        }

        .frame(height: 400)

        // Leave room for RuleMark annotations.
        .padding(.horizontal, 20)
        .padding(.top, 55)

        .onAppear { animateGraph() }

        .chartLegend(.hidden)

        // Support tapping on the plot area to see data point details.
        .chartOverlay { proxy in chartOverlay(proxy: proxy) }

        // Hide the x-axis and its labels.
        // TODO: Can you only hide the labels?
        .chartXAxis(.hidden)

        .if(canScaleYAxis(metric: metric)) { view in
            view
                // Change the y-axis to begin an minValue and end at maxValue.
                // This causes a crash for some metrics.
                .chartYScale(domain: minValue ... maxValue)

            // Stop AreaMarks from spilling outside chart.
            // But this cuts off the bottom half
            // of the bottom number on the y-axis!
            // .clipShape(Rectangle())
        }

        // Give the plot area a background color.
        .chartPlotStyle { content in
            content.background(Color(.secondarySystemBackground))
        }
    }

    private var chartTypePicker: some View {
        picker(
            label: "Chart Type",
            values: ["Bar", "Line"],
            selected: $chartType
        )
        .onChange(of: chartType) { _ in
            // Make a copy of data where "animate" is false in each item.
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

    private var dateDisplay: String {
        if timeSpan == "1 Day" { return selectedDate }
        let parts = selectedDate.components(separatedBy: " ")
        return parts.first ?? selectedDate
    }

    private var formattedValue: String {
        let intUnits: [HKUnit] = [.count(), .largeCalorie()]
        if intUnits.contains(metric.unit) {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            let value = Int(selectedValue)
            return numberFormatter.string(from: NSNumber(value: value))!
        }

        let format = "%.\(sd(metric.decimalPlaces))f"
        let isPercent = metric.unit == .percent()
        let value = isPercent ? selectedValue * 100 : selectedValue
        return String(format: format, value) + (isPercent ? "%" : "")
    }

    private var maxValue: Double {
        let item = data.max { $0.value < $1.value }
        return item?.value ?? 0.0
    }

    private var metricName: String {
        if metric.identifier == .respiratoryRate {
            return "breaths per minute"
        }
        return unitMap[metric.unit] ?? metric.unit.unitString
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
        let item = data.min { $0.value < $1.value }
        return item?.value ?? 0.0
    }

    private var startDate: Date {
        let today = Date().withoutTime
        return timeSpan == "1 Day" ? today.yesterday :
            timeSpan == "1 Week" ? today.daysBefore(7) :
            timeSpan == "1 Month" ? today.monthsBefore(1) :
            timeSpan == "3 Months" ? today.monthsBefore(3) :
            // For .headphoneAudioExposure I could get data for 25 days,
            // but asking for any more crashes the app with the error
            // "Unable to invalidate interval: no data source available".
            // I had a small amount of data from Apple Watch.
            // I couldn't view the data from iPhone ... maybe too much.
            // After deleting all of that data from the Health app,
            // I can now view that metric with "1 Month" selected.
            today
    }

    private var timeSpanPicker: some View {
        picker(
            label: "Time Span",
            values: ["1 Day", "1 Week", "1 Month", "3 Months"],
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
            case "3 Months":
                frequency = .week
            default:
                break
            }

            loadData()
        }
    }

    private var title: String {
        if metric.identifier == .bodyMass { return "Weight" }
        if metric.identifier == .vo2Max { return "VO2 Max" }

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
            Text(metricName)
            // Text("values go from \(minValue) to \(maxValue)")
            if data.count == 0 {
                Text("No data was found for this metric and time span. " +
                     "Perhaps you did not grant access to all health data.")
                    .padding(.top)
            } else {
                chart
            }
            Spacer()
        }
        .onOpenURL(perform: navigate)
        .padding()
        .task {
            await HealthStore().requestPermission()
            loadData()
        }
    }

    // MARK: - Methods

    private func animateGraph() {
        updateWidgets()

        for index in data.indices {
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

    private func annotationPosition(_ index: Int) -> AnnotationPosition {
        let percent = Double(index) / Double(data.count)
        return percent < 0.1 ? .topTrailing :
            percent > 0.95 ? .topLeading :
            .top
    }

    private func canScaleYAxis(metric: Metric) -> Bool {
        if chartType == "Bar" { return false }

        if metric.unit == .percent() { return false }

        // If the percent difference between the min and max values is very small,
        // setting the y-axis to only go from min to max causes the app to crash.
        let min = minValue
        let percentDifference = (maxValue - min) / min
        // print("percentDifference =", percentDifference)
        return percentDifference >= 0.1
    }

    private func chartOverlay(proxy: ChartProxy) -> some View {
        GeometryReader { _ in
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
        Log.info("entered")
        Task {
            do {
                let newData = try await HealthStore().getData(
                    identifier: metric.identifier,
                    startDate: startDate,
                    frequency: frequency
                ) { data in
                    metric.option == .cumulativeSum ?
                        data.sumQuantity() :
                        data.averageQuantity()
                }
                // All objects in data will now have "animate" set to false.

                dateToValueMap = [:]
                for item in newData {
                    dateToValueMap[item.date] = item.value
                }

                data = newData
                animateGraph()
            } catch {
                Log.error(error)
            }
        }
    }

    private func navigate(url: URL) {
        var name = ""
        switch url.absoluteString {
        case "distanceWalkingRunning":
            name = "Distance Walking & Running"
        case "stepCount":
            name = "Step Count"
        default:
            break
        }

        if let selected = Metrics.shared.metric(named: name) {
            metric = selected
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

    /*
     private func showLiveActivity() {
         /*
         guard let Activity.ActivityAuthorizationInfo.areActivitiesEnabled else {
             Log.shared.debug("Live activities are not enabled.")
             return
         }
         */

         let attributes = HealthAttributes(
             name: "Mark Volkmann"
         )
         let contentState =  HealthAttributes.LiveData(
             stepCount: 1234,
             miles: 0.62
         )
         do {
             let activity = try Activity<HealthAttributes>.request(
                 attributes: attributes,
                 contentState: contentState,
                 pushType: nil
             )
         } catch {
             Log.shared.error(error)
         }
     }

     private func updateLiveActivity() {
         let attributes = HealthAttributes.LiveData(
             stepCount: 1267,
             miles: 0.63
         )
         // await activity.update(using: updatedStatus)

         // To end the live activity,
         // await activity.end(dismissalPolicy: .immediate)
     }
     */

    private func updateWidgets() {
        // This reloads the timeline of all widgets associated with the app.
        WidgetCenter.shared.reloadAllTimelines()

        /* This approach can be used to only
            reload the timeline of some of the widgets.
         WidgetCenter.shared.getCurrentConfigurations { result in
             guard case .success(let widgets) = result else { return }
             for widget in widgets {
                 // Could just call this with a hardcoded widget kind value.
                 WidgetCenter.shared.reloadTimelines(ofKind: widget.kind)
             }
         }
         */
    }
}
