import MinehutKit
import SwiftUI
import UIKit

struct ServerDetailView: View {
    let id: String

    @State private var range: GraphRange = .day
    @State private var model = LoadModel<ServerDetailResponse>()
    @State private var copied = false

    var body: some View {
        List {
            if let detail = model.value {
                let server = detail.server
                Section {
                    HStack(spacing: 14) {
                        LetterBadge(name: server.name, size: 54)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.name).font(.title2.bold())
                            Text("\(Formatters.players(server.players, max: server.maxPlayers)) players")
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text(server.ip).font(.body.monospaced()).textSelection(.enabled)
                        Spacer()
                        Button(copied ? "Copied" : "Copy") {
                            UIPasteboard.general.string = server.ip
                            copied = true
                        }
                        .buttonStyle(.bordered)
                    }
                    if !server.categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(server.categories, id: \.self) { category in
                                    Text(category)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.quaternary, in: Capsule())
                                }
                            }
                        }
                    }
                } header: {
                    UpdatedHeader(updatedAt: detail.updatedAt, isOffline: model.isOffline, isLoading: model.isLoading)
                }

                Section("Players") {
                    Picker("Range", selection: $range) {
                        ForEach(GraphRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    PlayerChart(points: detail.points, range: detail.range).frame(height: 200)
                    if let peak = detail.peak {
                        LabeledContent(
                            "Peak",
                            value: "\(peak.players) at \(unixDate(peak.ts).formatted(date: .abbreviated, time: .shortened))"
                        )
                    }
                }

                let motd = MOTDFormatter.plainText(server.motd)
                if !motd.isEmpty {
                    Section("MOTD") { Text(motd).font(.callout) }
                }
                if let author = server.author {
                    Section { LabeledContent("Owner", value: author) }
                }
            } else if let error = model.error {
                ErrorStateView(error: error) { Task { await model.load(.server(id: id, range: range)) } }
            } else {
                LoadingRow()
            }
        }
        .navigationTitle(model.value?.server.name ?? "Server")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load(.server(id: id, range: range)) }
        .task(id: range) { await model.load(.server(id: id, range: range)) }
    }
}
