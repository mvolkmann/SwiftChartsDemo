import ActivityKit
import HealthKit
import Intents
import SwiftUI
import WidgetKit

struct HealthProvider: IntentTimelineProvider {
    private let store = HealthStore()

    func placeholder(in _: Context) -> HealthEntry {
        HealthEntry(
            date: Date(),
            stepCount: 5000,
            distance: 0.9,
            configuration: ConfigurationIntent()
        )
    }

    func getSnapshot(
        for _: ConfigurationIntent,
        in context: Context,
        completion: @escaping (HealthEntry) -> Void
    ) {
        /*
         let entry = HealthEntry(
             date: Date(),
             stepCount: 5000,
             configuration: configuration
         )
         completion(entry)
         */
        completion(placeholder(in: context))
    }

    private func getQuantityToday(
        for identifier: HKQuantityTypeIdentifier
    ) async -> Double {
        do {
            let data = try await store.getData(
                identifier: identifier,
                startDate: Calendar.current.startOfDay(for: Date()),
                frequency: Frequency.day
            ) { data in
                data.sumQuantity()
            }
            return data.first?.value ?? 0.0
        } catch {
            Log.shared.error(error)
            return 0
        }
    }

    func getTimeline(
        for configuration: ConfigurationIntent,
        in context: Context,
        completion: @escaping (Timeline<Entry>) -> Void
    ) {
        Task {
            // The app must be run at least once so it can
            // request authorization to access health data.
            // Until that happens, this widget cannot access health data.
            // The widget cannot request authorization.
            let stepCount = Int(await getQuantityToday(for: .stepCount))
            let distance = await getQuantityToday(for: .distanceWalkingRunning)

            let now = Date()
            let entries: [HealthEntry] = [
                HealthEntry(
                    date: now,
                    stepCount: stepCount,
                    distance: distance,
                    configuration: configuration
                )
            ]

            // Attempt to update the widget every minute, even though iOS will
            // likely not update more frequently than once every 15 minutes.
            // The widget is also updated every time
            // the chart displayed in the app is updated.
            // See the updateWidgets method in HealthChartView.swift.
            let later = now.addingTimeInterval(60) // seconds
            let timeline = Timeline(entries: entries, policy: .after(later))
            completion(timeline)
        }
    }
}

struct HealthEntry: TimelineEntry {
    let date: Date
    let stepCount: Int
    let distance: Double
    let configuration: ConfigurationIntent
}

struct HealthEntryView: View {
    @Environment(\.widgetFamily) var family

    var entry: HealthProvider.Entry

    var formattedDate: String {
        "\(entry.date.month) \(entry.date.dayOfMonth)"
    }

    var body: some View {
        ZStack {
            ContainerRelativeShape().fill(.blue.gradient)
            VStack {
                // These appear in every widget size.
                Text(formattedDate)
                    .font(.system(size: 24))
                    .fontWeight(.bold)
                Text(entry.date.time)
                Link(destination: URL(string: "stepCount")!) {
                    Text("Steps: \(entry.stepCount)")
                }

                switch family {
                case .systemMedium:
                    Link(destination: URL(string: "distanceWalkingRunning")!) {
                        Text(String(format: "Miles: %.2f", entry.distance))
                    }
                case .systemLarge:
                    Link(destination: URL(string: "distanceWalkingRunning")!) {
                        Text(String(format: "Miles: %.2f", entry.distance))
                    }
                    Text("Add more data here.")

                // These are for lock screen widgets.
                case .accessoryCircular:
                    HealthLockScreenWidget(family: family, entry: entry)
                case .accessoryInline:
                    HealthLockScreenWidget(family: family, entry: entry)
                case .accessoryRectangular:
                    HealthLockScreenWidget(family: family, entry: entry)

                default:
                    EmptyView()
                }
            }
            .font(.system(size: 24))
            .foregroundColor(.white)
        }
    }
}

struct HealthLockScreenWidget: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let family: WidgetFamily
    let entry: HealthEntry

    var body: some View {
        switch renderingMode {
        case .accented:
            Text("\(family.rawValue) accented")
                .foregroundColor(.orange)
                // Apply this to all views whose color
                // should be affected by the rendering mode.
                .widgetAccentable()
        case .fullColor:
            Text("\(family.rawValue) full color")
                .foregroundColor(.yellow)
                .widgetAccentable()
        case .vibrant:
            Text("\(family.rawValue) vibrant")
                .foregroundColor(.green)
                .widgetAccentable()
        default:
            EmptyView()
        }
    }
}

// @main // This must be removed when using a WidgetBundle.
struct HealthWidget: Widget {
    let kind: String = "MyHealthSnaphot"

    private var supportedFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [
            .systemSmall,
            .systemMedium,
            .systemLarge
        ]
        if #available(iOSApplicationExtension 16.0, *) {
            families.append(.accessoryCircular)
            families.append(.accessoryInline)
            families.append(.accessoryRectangular)
        } else {
            Log.shared.info("accessory families are NOT supported")
        }
        return families
    }

    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: ConfigurationIntent.self,
            provider: HealthProvider()
        ) { entry in
            HealthEntryView(entry: entry)
        }
        .configurationDisplayName("My Health")
        .description("This widget provides a snapshot of your HealthKit data.")
        .supportedFamilies(supportedFamilies)
    }
}

struct HealthPreviewProvider: PreviewProvider {
    static var previews: some View {
        HealthEntryView(
            entry: HealthEntry(
                date: Date(),
                stepCount: 5000,
                distance: 0.9,
                configuration: ConfigurationIntent()
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
