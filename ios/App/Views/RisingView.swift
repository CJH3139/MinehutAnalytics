import MinehutKit
import SwiftUI

struct RisingView: View {
    @State private var window: RisingWindow = .day
    @State private var model = LoadModel<RisingResponse>()
    @State private var search = ""
    var body: some View {
        List {
            Section {
                Text("Catch the next wave.").font(.title2.bold())
                Text("Communities gaining players over your selected window.").foregroundStyle(.secondary)
                Picker("Growth window", selection: $window) {
                    ForEach(RisingWindow.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
            }.listRowBackground(Color.clear)
            if let response = model.value {
                Section {
                    if !response.ready {
                        ContentUnavailableView("Building a baseline", systemImage: "clock", description: Text(response.readyAt.map { "Ready around \(Formatters.clockTime($0))." } ?? "More observations are needed to measure growth."))
                    } else {
                        let matches = Array(response.servers.enumerated()).filter { search.isEmpty || $0.element.name.localizedCaseInsensitiveContains(search) }
                        if matches.isEmpty {
                            ContentUnavailableView("No matching risers", systemImage: "chart.line.uptrend.xyaxis", description: Text(search.isEmpty ? "No observed player gains in this window." : "Try another server name."))
                        }
                        ForEach(matches, id: \.element.id) { index, server in
                            NavigationLink(value: server.id) {
                                ServerRowView(rank: index + 1, name: server.name, subtitle: "\(server.players.formatted()) players", trailing: Formatters.gain(server.gain, pct: server.pct), trailingColor: AnalyticsTheme.mint)
                            }.swipeActions { FavoriteButton(id: server.id, name: server.name) }
                        }
                    }
                } header: { UpdatedHeader(updatedAt: response.updatedAt, isOffline: model.isOffline, isLoading: model.isLoading) }.listRowBackground(AnalyticsTheme.surface)
            } else if let error = model.error { ErrorStateView(error: error) { Task { await model.load(.rising(window)) } } }
            else { LoadingRow() }
        }.analyticsList().navigationTitle("Rising").searchable(text: $search, prompt: "Search rising servers")
            .refreshable { await model.load(.rising(window)) }.task(id: window) { await model.load(.rising(window)) }
    }
}
