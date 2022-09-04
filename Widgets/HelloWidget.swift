import HealthKit
import Intents // TODO: need this?
import SwiftUI
import WidgetKit

private let defaultBackgroundColor: Color = .gray
private let defaultName = "World"

struct HelloProvider: IntentTimelineProvider {
    private let store = HealthStore()

    private let colors: [Color] = [defaultBackgroundColor, .red, .green, .blue]

    func color(index: Int) -> Color {
        index < colors.count ? colors[index] : defaultBackgroundColor
    }

    func getSnapshot(
        for _: ConfigurationIntent,
        in context: Context,
        completion: @escaping (HelloEntry) -> Void
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
            let entries: [HelloEntry] = [
                HelloEntry(
                    date: now,
                    name: name,
                    backgroundColor: color(index: colorIndex),
                    configuration: configuration // TODO: Needed?
                )
            ]

            let timeline = Timeline(entries: entries, policy: .never)
            completion(timeline)
        }
    }

    func placeholder(in _: Context) -> HelloEntry {
        HelloEntry(
            date: Date(),
            name: defaultName,
            backgroundColor: defaultBackgroundColor,
            configuration: ConfigurationIntent()
        )
    }
}

struct HelloEntry: TimelineEntry {
    let date: Date
    let name: String
    let backgroundColor: Color
    let configuration: ConfigurationIntent // TODO: Is this needed?
}

struct HelloEntryView: View {
    @Environment(\.widgetFamily) var family

    var entry: HelloProvider.Entry

    var body: some View {
        ZStack {
            ContainerRelativeShape().fill(.blue.gradient)
            VStack {
                // These appear in every widget size.
                Text(entry.date.time)
                Text("Hello, \(entry.name)!")

                switch family {
                case .systemMedium:
                    Text("Medium")
                case .systemLarge:
                    Text("Large")
                case .accessoryCircular:
                    HelloLockScreenWidget(family: family, entry: entry)
                case .accessoryInline:
                    HelloLockScreenWidget(family: family, entry: entry)
                case .accessoryRectangular:
                    HelloLockScreenWidget(family: family, entry: entry)
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
            Log.shared.info("accessory families are NOT supported")
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
            entry: HelloEntry(
                date: Date(),
                name: defaultName,
                backgroundColor: defaultBackgroundColor,
                configuration: ConfigurationIntent()
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
