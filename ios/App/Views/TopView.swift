import MinehutKit
import SwiftUI

struct TopView: View {
    @State private var model = LoadModel<TopResponse>()
    @State private var search = ""
    var body: some View {
        List {
            Section {
                Text("The communities drawing a crowd.").font(.title2.bold())
                Text("Ranked by current listed players. Changes compare with 24 hours ago.").font(.callout).foregroundStyle(.secondary)
                NavigationLink { CompareView() } label: { Label("Compare two servers", systemImage: "chart.xyaxis.line") }
            }.listRowBackground(Color.clear)
            if let response = model.value {
                Section {
                    let matches = Array(response.servers.enumerated()).filter { search.isEmpty || $0.element.name.localizedCaseInsensitiveContains(search) }
                    if matches.isEmpty { ContentUnavailableView.search(text: search) }
                    ForEach(matches, id: \.element.id) { index, server in
                        NavigationLink(value: server.id) {
                            ServerRowView(rank: index + 1, name: server.name, subtitle: "\(server.players.formatted()) players", trailing: Formatters.change(server.change24h), trailingColor: (server.change24h ?? 0) < 0 ? .orange : AnalyticsTheme.mint)
                        }.swipeActions { FavoriteButton(id: server.id, name: server.name) }
                    }
                } header: { UpdatedHeader(updatedAt: response.updatedAt, isOffline: model.isOffline, isLoading: model.isLoading) }.listRowBackground(AnalyticsTheme.surface)
            } else if let error = model.error { ErrorStateView(error: error) { Task { await model.load(.top) } } }
            else { LoadingRow() }
        }.analyticsList().navigationTitle("Top servers").searchable(text: $search, prompt: "Search top servers")
            .refreshable { await model.load(.top) }.task { await model.load(.top) }
    }
}
