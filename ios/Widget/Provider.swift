import MinehutKit
import WidgetKit

struct WidgetEntry: TimelineEntry {
    let date: Date
    let kind: WidgetListKind
    let content: WidgetContent?
    let isOffline: Bool
    let message: String?

    static func rowLimit(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall, .accessoryInline: return 1
        case .accessoryRectangular: return 2
        case .systemLarge: return 8
        default: return 3
        }
    }

    init(date: Date, kind: WidgetListKind, content: WidgetContent?, isOffline: Bool, message: String?) {
        self.date = date
        self.kind = kind
        self.content = content
        self.isOffline = isOffline
        self.message = message
    }

    init<T: Sendable>(kind: WidgetListKind, result: Loaded<T>, limit: Int, map: (T, Int) -> WidgetContent) {
        switch result {
        case .fresh(let value):
            self.init(date: .now, kind: kind, content: map(value, limit), isOffline: false, message: nil)
        case .cached(let value, _):
            self.init(date: .now, kind: kind, content: map(value, limit), isOffline: true, message: nil)
        case .failed(let error):
            self.init(
                date: .now,
                kind: kind,
                content: nil,
                isOffline: false,
                message: error == .noData ? "No data yet" : "Can't reach server"
            )
        }
    }

    static var sample: WidgetEntry {
        let names = ["TechMines", "MineRefine", "Clickerking", "RizzMines", "FlowerRealms", "EssenceMCC", "MoneyRealms", "Raidfight"]
        let rows = names.enumerated().map { index, name in
            WidgetRow(
                id: name,
                rank: index + 1,
                name: name,
                players: 240 - index * 25,
                delta: "+\(45 - index * 5) (↑\(30 - index * 3)%)",
                shortDelta: "+\(45 - index * 5)"
            )
        }
        let content = WidgetContent(
            kind: .rising,
            updatedAt: Int(Date().timeIntervalSince1970),
            ready: true,
            rows: rows,
            inlineText: "↑ TechMines +45"
        )
        return WidgetEntry(date: .now, kind: .rising, content: content, isOffline: false, message: nil)
    }
}

struct Provider: AppIntentTimelineProvider {
    private let loader: Loader? = APIClient.fromBundle().map { Loader(client: $0, cache: .standard()) }

    func placeholder(in context: Context) -> WidgetEntry {
        .sample
    }

    func snapshot(for configuration: MinehutWidgetIntent, in context: Context) async -> WidgetEntry {
        if context.isPreview { return .sample }
        return await makeEntry(for: configuration, family: context.family)
    }

    func timeline(for configuration: MinehutWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let entry = await makeEntry(for: configuration, family: context.family)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
    }

    private func makeEntry(for configuration: MinehutWidgetIntent, family: WidgetFamily) async -> WidgetEntry {
        let kind = configuration.list.kind
        let limit = WidgetEntry.rowLimit(for: family)
        guard let loader else {
            return WidgetEntry(date: .now, kind: kind, content: nil, isOffline: false, message: "Missing Worker URL")
        }
        switch configuration.list {
        case .rising:
            let result = await loader.load(RisingResponse.self, .rising(configuration.window.risingWindow))
            return WidgetEntry(kind: kind, result: result, limit: limit, map: WidgetContent.rising(_:limit:))
        case .top where family == .systemLarge:
            let result = await loader.load(TopSeriesResponse.self, .topSeries)
            return WidgetEntry(kind: kind, result: result, limit: limit, map: WidgetContent.topSeries(_:limit:))
        case .top:
            let result = await loader.load(TopResponse.self, .top)
            return WidgetEntry(kind: kind, result: result, limit: limit, map: WidgetContent.top(_:limit:))
        }
    }
}
