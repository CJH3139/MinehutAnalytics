import MinehutKit
import SwiftUI

struct RisingView: View {
    @State private var window: RisingWindow = .day
    @State private var model = LoadModel<RisingResponse>()

    var body: some View {
        List {
            Picker("Window", selection: $window) {
                ForEach(RisingWindow.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            if let response = model.value {
                Section {
                    if !response.ready {
                        Text(notReadyText(response.readyAt)).foregroundStyle(.secondary)
                    } else if response.servers.isEmpty {
                        Text("No servers gained players in the last \(response.window.rawValue).").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(response.servers.enumerated()), id: \.element.id) { index, server in
                            NavigationLink(value: server.id) {
                                ServerRowView(
                                    rank: index + 1,
                                    name: server.name,
                                    subtitle: "\(server.players) players",
                                    trailing: Formatters.gain(server.gain, pct: server.pct),
                                    trailingColor: .green
                                )
                            }
                        }
                    }
                } header: {
                    UpdatedHeader(updatedAt: response.updatedAt, isOffline: model.isOffline, isLoading: model.isLoading)
                }
            } else if let error = model.error {
                ErrorStateView(error: error) { Task { await model.load(.rising(window)) } }
            } else {
                LoadingRow()
            }
        }
        .navigationTitle("Rising")
        .refreshable { await model.load(.rising(window)) }
        .task(id: window) { await model.load(.rising(window)) }
    }

    private func notReadyText(_ readyAt: Int?) -> String {
        guard let readyAt else { return "Collecting data. Check back soon." }
        return "Collecting data. Ready around \(Formatters.clockTime(readyAt))."
    }
}
