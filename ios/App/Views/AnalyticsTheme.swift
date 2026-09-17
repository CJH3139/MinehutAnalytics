import SwiftUI
import MinehutKit

enum AnalyticsTheme {
    static let background = Color(red: 0.025, green: 0.055, blue: 0.105)
    static let surface = Color(red: 0.055, green: 0.10, blue: 0.17)
    static let cyan = Color(red: 0.27, green: 0.84, blue: 0.98)
    static let mint = Color(red: 0.39, green: 0.95, blue: 0.73)
}

extension View {
    func analyticsList() -> some View {
        self.scrollContentBackground(.hidden)
            .background(AnalyticsTheme.background)
            .listStyle(.insetGrouped)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    var note: String? = nil
    var color: Color = AnalyticsTheme.cyan
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.title, design: .rounded, weight: .bold)).monospacedDigit().foregroundStyle(color)
            if let note { Text(note).font(.caption2).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AnalyticsTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

struct RangePicker: View {
    @Binding var range: GraphRange
    var body: some View {
        Picker("History range", selection: $range) {
            ForEach(GraphRange.allCases) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented)
    }
}

struct FavoriteButton: View {
    @Environment(FavoritesModel.self) private var favorites
    let id: String
    let name: String
    var body: some View {
        Button { favorites.toggle(id: id, name: name) } label: {
            Label(favorites.collection.contains(id) ? "Remove from Watchlist" : "Save to Watchlist", systemImage: favorites.collection.contains(id) ? "star.fill" : "star")
        }.tint(AnalyticsTheme.mint)
    }
}
