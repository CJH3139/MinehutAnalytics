import MinehutKit
import SwiftUI
import UIKit

struct ServerDetailView: View {
    let id: String
    @State private var range: GraphRange = .day
    @State private var model = LoadModel<ServerDetailResponse>()
    @State private var copied = false
    private var requestKey: String { "\(id)|\(range.rawValue)" }
    var body: some View {
        List {
            Section { RangePicker(range: $range) }.listRowBackground(Color.clear)
            if let detail = model.value {
                let server = detail.server
                Section {
                    HStack(spacing: 16) {
                        ServerAvatar(icon: server.icon, size: 60)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(server.name).font(.system(.title2, design: .rounded, weight: .bold))
                            Text("\(Formatters.players(server.players, max: server.maxPlayers)) players").foregroundStyle(AnalyticsTheme.mint).monospacedDigit()
                        }
                    }.padding(.vertical, 8)
                    HStack {
                        Text(server.ip).font(.callout.monospaced()).textSelection(.enabled)
                        Spacer()
                        Button(copied ? "Copied" : "Copy") { UIPasteboard.general.string = server.ip; copied = true }.buttonStyle(.bordered)
                    }
                    FavoriteButton(id: server.id, name: server.name, icon: server.icon)
                    if !server.categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(Set(server.categories)).sorted(), id: \.self) { category in
                                    Text(category).font(.caption).padding(.horizontal, 10).padding(.vertical, 6).background(AnalyticsTheme.cyan.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                } header: { UpdatedHeader(updatedAt: detail.updatedAt, isOffline: model.isOffline, isLoading: model.isLoading) }.listRowBackground(AnalyticsTheme.surface)
                Section {
                    PlayerChart(points: detail.points, range: detail.range, updatedAt: detail.updatedAt).frame(height: 230)
                    Text(detail.range == .day ? "Observed players over 24h. Gaps indicate missing samples." : "Hourly player peaks over \(detail.range.rawValue). Gaps indicate missing observations.").font(.caption).foregroundStyle(.secondary)
                } header: { Text("Player history · \(detail.range.rawValue)") }.listRowBackground(AnalyticsTheme.surface)
                let stats = ObservationStatistics(points: detail.points)
                Section {
                    LabeledContent("Observed peak", value: stats.peak.map { $0.formatted() } ?? "Unavailable")
                    LabeledContent(detail.range == .day ? "Observed average" : "Mean hourly peak", value: stats.mean.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "Unavailable")
                    LabeledContent(detail.range == .day ? "Lowest observation" : "Lowest hourly peak", value: stats.minimum.map { $0.formatted() } ?? "Unavailable")
                    LabeledContent("First to last observation", value: stats.change.map { Formatters.change($0) } ?? "Unavailable")
                    LabeledContent("Observations", value: stats.count.formatted())
                    Text("Based only on available observations in \(detail.range.rawValue); not a measure of uptime or unique visitors.").font(.caption).foregroundStyle(.secondary)
                    Text("Listings may omit servers; gaps or zero values do not prove downtime.").font(.caption).foregroundStyle(.secondary)
                } header: { Text("Range statistics · \(detail.range.rawValue)") }.listRowBackground(AnalyticsTheme.surface)
                let motd = MOTDFormatter.plainText(server.motd)
                Section {
                    if !motd.isEmpty { Text(motd).font(.callout) }
                    if let author = server.author { LabeledContent("Owner", value: author) }
                    LabeledContent("First observed", value: unixDate(server.firstSeen).formatted(date: .abbreviated, time: .omitted))
                } header: { Text("About this server") }.listRowBackground(AnalyticsTheme.surface)
            } else if let error = model.error {
                ErrorStateView(error: error) { Task { await model.load(.server(id: id, range: range)) } }
            } else { LoadingRow() }
        }.analyticsList().navigationTitle(model.value?.server.name ?? "Server").navigationBarTitleDisplayMode(.inline)
            .refreshable { await model.load(.server(id: id, range: range)) }
            .task(id: requestKey) { copied = false; await model.load(.server(id: id, range: range)) }
    }
}
