import HealthKit
import SwiftUI
import WidgetKit

private let defaultBackgroundColor: Color = .gray
private let defaultName = "World"

struct HelloProvider: IntentTimelineProvider {
    typealias Entry = HelloEntry

    static let mockEntry = Entry(
        date: Date(),
        configuration: ConfigurationIntent(),
        name: defaultName,
        backgroundColor: defaultBackgroundColor
    )

    private let store = HealthStore()

    private let colors: [Color] = [defaultBackgroundColor, .red, .green, .blue]

    func color(index: Int) -> Color {
        index < colors.count ? colors[index] : defaultBackgroundColor
    }

    func getSnapshot(
        for _: ConfigurationIntent,
        in context: Context,
        completion: @escaping (Entry) -> Void
    ) {
        completion(placeholder(in: context))
    }

    func getTimeline(
        for configuration: ConfigurationIntent,
        in _: Context,
        completion: @escaping (Timeline<Entry>) -> Void
    ) {
        Task {
            let now = Date()
            let name = configuration
                .value(forKey: "name") as? String ?? "unknown"
            let colorIndex = configuration
                .value(forKey: "backgroundColorIndex") as? Int ?? 0
            let entries: [Entry] = [
                Entry(
                    date: now,
                    configuration: configuration,
                    name: name,
                    backgroundColor: color(index: colorIndex)
                )
            ]

            let timeline = Timeline(entries: entries, policy: .never)
            completion(timeline)
        }
    }

    func placeholder(in _: Context) -> Entry {
        HelloProvider.mockEntry
    }
}

struct HelloEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let name: String
    let backgroundColor: Color
}

struct HelloEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily

    var entry: HelloProvider.Entry

    var body: some View {
        ZStack {
            ContainerRelativeShape().fill(.blue.gradient)
            VStack {
                // These appear in every widget size.
                Text(entry.date.time)
                Text("Hello, \(entry.name)!")

                switch widgetFamily {
                case .systemMedium:
                    Text("Medium")
                case .systemLarge:
                    Text("Large")
                case .accessoryCircular:
                    HelloLockScreenWidget(family: widgetFamily, entry: entry)
                case .accessoryInline:
                    HelloLockScreenWidget(family: widgetFamily, entry: entry)
                case .accessoryRectangular:
                    HelloLockScreenWidget(family: widgetFamily, entry: entry)
                default:
                    EmptyView()
                }
            }
            // Fill entire widget.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(entry.backgroundColor)
            .foregroundColor(.white)
            .font(.system(size: 24))
        }
    }
}

struct HelloLockScreenWidget: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let family: WidgetFamily
    let entry: HelloEntry

    private var color: Color {
        switch renderingMode {
        case .accented:
            return .orange
        case .fullColor:
            return .red
        case .vibrant:
            return .purple
        default:
            return .gray
        }
    }

    var body: some View {
        VStack {
            // Text("Hello")
            Text(entry.name)
        }
        .widgetAccentable()
        // Fill entire widget.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(entry.backgroundColor)
        .foregroundColor(color)
        .font(.system(size: 10))
    }
}

// @main // This must be removed when using a WidgetBundle.
struct HelloWidget: Widget {
    let kind: String = "Hello"

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
            Log.info("accessory families are NOT supported")
        }
        return families
    }

    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: ConfigurationIntent.self,
            provider: HelloProvider()
        ) { entry in
            HelloEntryView(entry: entry)
        }
        .configurationDisplayName("Hello")
        .description("This is a simple demonstration widget.")
        .supportedFamilies(supportedFamilies)
    }
}

struct HelloPreviewProvider: PreviewProvider {
    static var previews: some View {
        HelloEntryView(
            entry: HelloProvider.mockEntry
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
