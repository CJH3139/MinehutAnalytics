import Foundation

public enum Formatters {
    public static func gain(_ gain: Int, pct: Double?) -> String {
        guard let pct else { return "+\(gain) (new)" }
        return "+\(gain) (↑\(Int(pct.rounded()))%)"
    }

    public static func change(_ change: Int?) -> String {
        guard let change else { return "" }
        return change > 0 ? "+\(change)" : "\(change)"
    }

    public static func players(_ players: Int, max: Int?) -> String {
        guard let max, max > 0 else { return "\(players)" }
        return "\(players) / \(max)"
    }

    public static func relative(from ts: Int, now: Date) -> String {
        let seconds = Swift.max(0, Int(now.timeIntervalSince1970) - ts)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }

    public static func updated(_ ts: Int, now: Date) -> String {
        "Updated \(relative(from: ts, now: now))"
    }

    public static func clockTime(_ ts: Int, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: unixDate(ts))
    }
}
