import HealthKit
import Intents
import SwiftUI
import WidgetKit

struct Provider: IntentTimelineProvider {
    private let store = HealthStore()

    func placeholder(in context: Context) -> MyEntry {
        MyEntry(
            date: Date(),
            stepCount: 5000,
            distance: 0.9,
            configuration: ConfigurationIntent()
        )
    }

    func getSnapshot(
        for configuration: ConfigurationIntent,
        in context: Context,
        completion: @escaping (MyEntry) -> ()
    ) {
        /*
        let entry = MyEntry(
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
            print("error getting health data:", error)
            return 0
        }
    }

    func getTimeline(
        for configuration: ConfigurationIntent,
        in context: Context,
        completion: @escaping (Timeline<Entry>) -> ()
    ) {
        print("My_Health_Snapshot.getTimeLine: entered")
        Task {
            // The app must be run at least once so it can
            // request authorization to access health data.
            // Until that happens, this widget cannot access health data.
            // The widget cannot request authorization.
            let stepCount = Int(await getQuantityToday(for: .stepCount))
            print("My_Health_Snapshot.getTimeLine: stepCount =", stepCount)
            let distance = await getQuantityToday(for: .distanceWalkingRunning)
            print("My_Health_Snapshot.getTimeLine: distance =", distance)

            let now = Date()
            let entries: [MyEntry] = [
                MyEntry(
                    date: now,
                    stepCount: stepCount,
                    distance: distance,
                    configuration: configuration
                )
            ]

            // Update the widget every minute for now.
            // TODO: This is only running one time!
            let later = now.addingTimeInterval(60) // seconds
            let timeline = Timeline(entries: entries, policy: .after(later))
            completion(timeline)
        }
    }
}

struct MyEntry: TimelineEntry {
    let date: Date
    let stepCount: Int
    let distance: Double
    let configuration: ConfigurationIntent
}

struct MyHealthSnaphotEntryView : View {
    @Environment(\.widgetFamily) var family

    var entry: Provider.Entry

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
                Text("Steps: \(entry.stepCount)")

                switch family {
                case .systemMedium:
                    Text(String(format: "Miles: %.2f", entry.distance))
                case .systemLarge:
                    Text(String(format: "Miles: %.2f", entry.distance))
                    Text("Add more data here.")
                default:
                    EmptyView()
                }
            }
            .font(.system(size: 24))
            .foregroundColor(.white)
        }
    }
}

@main
struct MyHealthSnaphot: Widget {
    let kind: String = "MyHealthSnaphot"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            MyHealthSnaphotEntryView(entry: entry)
        }
        .configurationDisplayName("My Health Snapshot")
        .description("This widget provides a snapshot of your HealthKit data.")
    }
}

struct MyHealthSnaphot_Previews: PreviewProvider {
    static var previews: some View {
        MyHealthSnaphotEntryView(
            entry: MyEntry(
                date: Date(),
                stepCount: 5000,
                distance: 0.9,
                configuration: ConfigurationIntent()
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}

