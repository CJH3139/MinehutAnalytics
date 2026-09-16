import MinehutKit
import SwiftUI

struct TopView: View {
    @State private var model = LoadModel<TopResponse>()
    @State private var stats = LoadModel<StatsResponse>()

    var body: some View {
        List {
            if let totals = stats.value {
                Section {
                    HStack {
                        StatTile(title: "Players online", value: totals.totalPlayers)
                        StatTile(title: "Servers online", value: totals.totalServers)
                    }
                }
            }

            if let response = model.value {
                Section {
                    ForEach(Array(response.servers.enumerated()), id: \.element.id) { index, server in
                        NavigationLink(value: server.id) {
                            ServerRowView(
                                rank: index + 1,
                                name: server.name,
                                subtitle: "\(Formatters.players(server.players, max: server.maxPlayers)) players",
                                trailing: Formatters.change(server.change24h),
                                trailingColor: changeColor(server.change24h)
                            )
                        }
                    }
                } header: {
                    UpdatedHeader(updatedAt: response.updatedAt, isOffline: model.isOffline, isLoading: model.isLoading)
                }
            } else if let error = model.error {
                ErrorStateView(error: error) { Task { await reload() } }
            } else {
                LoadingRow()
            }
        }
        .navigationTitle("Top")
        .refreshable { await reload() }
        .task { await reload() }
    }

    private func reload() async {
        await model.load(.top)
        await stats.load(.stats)
    }

    private func changeColor(_ change: Int?) -> Color {
        guard let change, change != 0 else { return .secondary }
        return change > 0 ? .green : .red
    }
}

private struct StatTile: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.formatted()).font(.title2.bold().monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
