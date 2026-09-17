import MinehutKit
import SwiftUI

struct ServerAvatar: View {
    let icon: String?
    var serverID: String? = nil
    var size: CGFloat = 34
    @State private var details = LoadModel<ServerDetailResponse>()

    var body: some View {
        AsyncImage(url: ServerIcon.url(for: icon ?? details.value?.server.icon)) { image in
            image.resizable().interpolation(.none).scaledToFit()
        } placeholder: {
            Image(systemName: "server.rack").font(.system(size: size * 0.45)).foregroundStyle(.secondary)
        }
        .frame(width: size, height: size)
        .background(AnalyticsTheme.surface, in: RoundedRectangle(cornerRadius: size * 0.22))
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .accessibilityHidden(true)
        .task(id: serverID) {
            if icon == nil, let serverID { await details.load(.server(id: serverID, range: .day)) }
        }
    }
}

struct ServerRowView: View {
    let rank: Int
    let name: String
    let icon: String?
    let subtitle: String
    let trailing: String
    let trailingColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            ServerAvatar(icon: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline).lineLimit(1)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(trailing)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(trailingColor)
        }
        .padding(.vertical, 7)
    }
}
