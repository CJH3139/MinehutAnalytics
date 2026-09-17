import Foundation

public enum ServerIcon {
    /// Official Minehut server-list artwork. Only allow an icon key, never a supplied URL.
    public static func url(for icon: String?) -> URL? {
        guard let icon, !icon.isEmpty, icon.count <= 128,
              icon.unicodeScalars.allSatisfy({ (65...90).contains($0.value) || (48...57).contains($0.value) || $0.value == 95 }) else { return nil }
        return URL(string: "https://minehut-server-icons-live.s3.us-west-2.amazonaws.com/\(icon).png")
    }
}
