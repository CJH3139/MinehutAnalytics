import MinehutKit
import SwiftUI

struct TopView: View {
    @State private var model = LoadModel<TopResponse>()
    @State private var search = ""
    var body: some View {
        List {
            Section {
                NavigationLink { CompareView() } label: { Label("Compare two servers", systemImage: "chart.xyaxis.line") }
            }.listRowBackground(Color.clear)
            if let response = model.value {
                Section {
                    let matches = Array(response.servers.enumerated()).filter { search.isEmpty || $0.element.name.localizedCaseInsensitiveContains(search) }
                    if matches.isEmpty { ContentUnavailableView.search(text: search) }
                    ForEach(matches, id: \.element.id) { index, server in
                        NavigationLink(value: server.id) {
                            ServerRowView(rank: index + 1, name: server.name, icon: server.icon, subtitle: "\(server.players.formatted()) players", trailing: Formatters.change(server.change24h), trailingColor: (server.change24h ?? 0) < 0 ? .orange : AnalyticsTheme.mint)
                        }.swipeActions { FavoriteButton(id: server.id, name: server.name, icon: server.icon) }
                    }
                } header: { UpdatedHeader(updatedAt: response.updatedAt, isOffline: model.isOffline, isLoading: model.isLoading) }.listRowBackground(AnalyticsTheme.surface)
            } else if let error = model.error { ErrorStateView(error: error) { Task { await model.load(.top) } } }
            else { LoadingRow() }
        }.analyticsList().navigationTitle("Top servers").searchable(text: $search, prompt: "Search top servers")
            .refreshable { await model.load(.top) }.task { await model.load(.top) }
    }
}
