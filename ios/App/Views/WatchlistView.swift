import MinehutKit
import SwiftUI

struct WatchlistView: View {
    @Environment(FavoritesModel.self) private var favorites
    @State private var top = LoadModel<TopResponse>()
    var body: some View {
        List {
            Section {
                Text("Your corner of Minehut.").font(.title2.bold())
                Text("Saved on this device. Save servers from rankings or their detail page.").foregroundStyle(.secondary)
            }.listRowBackground(Color.clear)
            if favorites.collection.servers.isEmpty {
                ContentUnavailableView("Keep your favorites close", systemImage: "star", description: Text("Open a server and tap the star to start your Watchlist."))
            } else {
                Section {
                    NavigationLink { CompareView() } label: { Label("Compare servers", systemImage: "chart.xyaxis.line") }
                    ForEach(favorites.collection.servers) { saved in
                        let current = top.value?.servers.first { $0.id == saved.id }
                        NavigationLink(value: saved.id) {
                            HStack(spacing: 12) {
                                LetterBadge(name: saved.name)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(current?.name ?? saved.name).font(.headline)
                                    Text(current.map { "\($0.players.formatted()) players in latest listing" } ?? "Open to check activity").font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 5)
                        }.swipeActions { FavoriteButton(id: saved.id, name: saved.name) }
                    }
                } header: {
                    if let response = top.value { UpdatedHeader(updatedAt: response.updatedAt, isOffline: top.isOffline, isLoading: top.isLoading) }
                    else { Text("Saved servers") }
                }.listRowBackground(AnalyticsTheme.surface)
                if top.error != nil { Text("Listing updates are unavailable. Your saved servers are still here.").font(.caption).foregroundStyle(.secondary) }
            }
        }.analyticsList().navigationTitle("Watchlist").task { await top.load(.top) }.refreshable { await top.load(.top) }
    }
}
