import Foundation

public enum AppRoute: Equatable, Sendable {
    case rising
    case top
    case server(id: String)

    public static let scheme = "minehutanalytics"

    public init?(url: URL) {
        guard url.scheme == AppRoute.scheme else { return nil }
        switch url.host {
        case "rising":
            self = .rising
        case "top":
            self = .top
        case "server":
            guard let id = url.pathComponents.first(where: { $0 != "/" }), !id.isEmpty else { return nil }
            self = .server(id: id)
        default:
            return nil
        }
    }

    public var url: URL {
        switch self {
        case .rising: return URL(string: "\(AppRoute.scheme)://rising")!
        case .top: return URL(string: "\(AppRoute.scheme)://top")!
        case .server(let id): return URL(string: "\(AppRoute.scheme)://server/\(id)")!
        }
    }
}
