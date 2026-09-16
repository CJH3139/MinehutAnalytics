import MinehutKit
import SwiftUI

@main
struct MinehutAnalyticsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    enum Tab: Hashable {
        case rising
        case top
    }

    @State private var tab: Tab = .rising
    @State private var risingPath: [String] = []
    @State private var topPath: [String] = []

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $risingPath) {
                RisingView()
                    .navigationDestination(for: String.self) { ServerDetailView(id: $0) }
            }
            .tabItem { Label("Rising", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(Tab.rising)

            NavigationStack(path: $topPath) {
                TopView()
                    .navigationDestination(for: String.self) { ServerDetailView(id: $0) }
            }
            .tabItem { Label("Top", systemImage: "trophy") }
            .tag(Tab.top)
        }
        .onOpenURL { url in
            guard let route = AppRoute(url: url) else { return }
            switch route {
            case .rising:
                tab = .rising
            case .top:
                tab = .top
            case .server(let id):
                tab = .rising
                risingPath = [id]
            }
        }
    }
}
