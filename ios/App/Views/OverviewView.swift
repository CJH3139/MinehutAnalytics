import MinehutKit
import SwiftUI

struct OverviewView: View {
    @State private var range: GraphRange = .day
    @State private var model = LoadModel<OverviewResponse>()
    @State private var stats = LoadModel<StatsResponse>()
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("MINEHUT ANALYTICS", systemImage: "sparkle").font(.caption.weight(.bold)).tracking(2).foregroundStyle(AnalyticsTheme.mint)
                    Text("A pulse on the network.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Explore activity. Find your next community.").foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }.listRowBackground(Color.clear)
            Section { RangePicker(range: $range) }.listRowBackground(Color.clear)
            if let value = model.value {
                Section {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top) { playerTile(value); serverTile(value) }
                        VStack { playerTile(value); serverTile(value) }
                    }
                } header: { UpdatedHeader(updatedAt: value.updatedAt, isOffline: model.isOffline, isLoading: model.isLoading) }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                Section {
                    PlayerChart(points: value.points.map { GraphPoint(ts: $0.ts, players: $0.players) }, range: range, gapTolerance: 1350, updatedAt: value.updatedAt).frame(height: 220)
                    Text("Network players · \(range.rawValue). Gaps indicate missing observations; history builds as samples arrive.").font(.caption).foregroundStyle(.secondary)
                } header: { Text("Network history") }
                .listRowBackground(AnalyticsTheme.surface)
                Section {
                    LabeledContent("Players on listed servers", value: value.listedPlayers.formatted())
                    LabeledContent("Active listed servers", value: value.activeServers.formatted())
                    LabeledContent("Top 10 share", value: value.top10Share.map { $0.formatted(.number.precision(.fractionLength(1))) + "%" } ?? "Unavailable")
                    Text("Top 10 share measures concentration among listed players, not the entire network.").font(.caption).foregroundStyle(.secondary)
                } header: { Text("Inside the listings") }.listRowBackground(AnalyticsTheme.surface)
                Section {
                    if value.categories.isEmpty { Text("No category observations yet.").foregroundStyle(.secondary) }
                    ForEach(value.categories) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text(category.name).font(.subheadline.weight(.semibold)); Spacer(); Text(category.players.formatted()).monospacedDigit().foregroundStyle(AnalyticsTheme.mint) }
                            ProgressView(value: Double(category.players), total: Double(max(value.listedPlayers, category.players, 1))).tint(AnalyticsTheme.mint)
                            Text("\(category.servers.formatted()) listed servers").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                    Text("First listed category of each returned server. These are listing observations, not network-wide totals.").font(.caption).foregroundStyle(.secondary)
                } header: { Text("Communities by category") }.listRowBackground(AnalyticsTheme.surface)
            } else {
                if let totals = stats.value {
                    Section {
                        MetricTile(title: "Network players", value: totals.totalPlayers.formatted())
                        MetricTile(title: "Network servers", value: totals.totalServers.formatted(), color: AnalyticsTheme.mint)
                    } header: { UpdatedHeader(updatedAt: totals.updatedAt, isOffline: stats.isOffline, isLoading: stats.isLoading) }.listRowBackground(Color.clear)
                }
                if let error = model.error {
                    Section {
                        Label("Network history unavailable", systemImage: "chart.xyaxis.line").font(.headline)
                        Text("History is not available yet. You can still explore rankings and saved servers.").font(.callout).foregroundStyle(.secondary)
                        Text(error.message).font(.caption).foregroundStyle(.secondary)
                        Button("Try again") { Task { await reload() } }
                    }.listRowBackground(AnalyticsTheme.surface)
                } else { LoadingRow() }
            }
        }.analyticsList().navigationTitle("Overview").navigationBarTitleDisplayMode(.inline)
            .refreshable { await reload() }.task(id: range) { await reload() }
    }
    private func playerTile(_ value: OverviewResponse) -> some View {
        MetricTile(title: "Network players", value: value.totalPlayers.formatted(), note: changeNote(value.playersChange24h))
    }
    private func serverTile(_ value: OverviewResponse) -> some View {
        MetricTile(title: "Network servers", value: value.totalServers.formatted(), note: changeNote(value.serverChange24h), color: AnalyticsTheme.mint)
    }
    private func changeNote(_ change: Int?) -> String {
        change.map { "\($0 >= 0 ? "+" : "")\($0.formatted()) vs 24h ago" } ?? "24h comparison not available"
    }
    private func reload() async {
        async let overview: () = model.load(.overview(range))
        async let totals: () = stats.load(.stats)
        _ = await (overview, totals)
    }
}
