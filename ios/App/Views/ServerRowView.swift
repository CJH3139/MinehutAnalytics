import SwiftUI

struct LetterBadge: View {
    let name: String
    var size: CGFloat = 34

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
            .foregroundStyle(AnalyticsTheme.background)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.28))
    }

    private var color: Color {
        let palette: [Color] = [AnalyticsTheme.cyan, AnalyticsTheme.mint, .teal, .blue]
        let hash = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fff_ffff }
        return palette[hash % palette.count]
    }
}

struct ServerRowView: View {
    let rank: Int
    let name: String
    let subtitle: String
    let trailing: String
    let trailingColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            LetterBadge(name: name)
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
