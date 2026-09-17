import MinehutKit
import SwiftUI

@main
struct MinehutAnalyticsApp: App {
    @State private var favorites = FavoritesModel()
    var body: some Scene {
        WindowGroup {
            RootView().environment(favorites).tint(AnalyticsTheme.cyan).preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    enum Tab: Hashable { case overview, rising, top, watchlist }
    @State private var tab: Tab = .overview
    @State private var risingPath: [String] = []
    @State private var topPath: [String] = []
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                OverviewView().navigationDestination(for: String.self) { ServerDetailView(id: $0) }
            }.tabItem { Label("Overview", systemImage: "square.grid.2x2") }.tag(Tab.overview)
            NavigationStack(path: $risingPath) {
                RisingView().navigationDestination(for: String.self) { ServerDetailView(id: $0) }
            }.tabItem { Label("Rising", systemImage: "chart.line.uptrend.xyaxis") }.tag(Tab.rising)
            NavigationStack(path: $topPath) {
                TopView().navigationDestination(for: String.self) { ServerDetailView(id: $0) }
            }.tabItem { Label("Top", systemImage: "trophy") }.tag(Tab.top)
            NavigationStack {
                WatchlistView().navigationDestination(for: String.self) { ServerDetailView(id: $0) }
            }.tabItem { Label("Watchlist", systemImage: "star") }.tag(Tab.watchlist)
        }
        .onOpenURL { url in
            guard let route = AppRoute(url: url) else { return }
            switch route {
            case .rising: tab = .rising
            case .top: tab = .top
            case .server(let id): tab = .rising; risingPath = [id]
            }
        }
    }
}
