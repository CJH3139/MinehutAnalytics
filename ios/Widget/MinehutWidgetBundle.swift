import SwiftUI
import WidgetKit

@main
struct MinehutWidgetBundle: WidgetBundle {
    var body: some Widget {
        MinehutAnalyticsWidget()
    }
}

struct MinehutAnalyticsWidget: Widget {
    let kind = "MinehutAnalyticsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MinehutWidgetIntent.self, provider: Provider()) { entry in
            MinehutWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Minehut Analytics")
        .description("Rising or top Minehut servers.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}
