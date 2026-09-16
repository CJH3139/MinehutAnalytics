import Foundation

public enum APIError: Error, Equatable, Sendable {
    case http(status: Int)
    case noData
    case decoding
    case transport(String)
}

public struct APIClient: Sendable {
    public enum Endpoint: Sendable, Equatable {
        case top
        case topSeries
        case stats
        case rising(RisingWindow)
        case server(id: String, range: GraphRange)

        public var cacheKey: String {
            switch self {
            case .top: return "top"
            case .topSeries: return "top_series"
            case .stats: return "stats"
            case .rising(let window): return "rising_\(window.rawValue)"
            case .server(let id, let range): return "server_\(id)_\(range.rawValue)"
            }
        }
    }

    public let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public static func fromBundle(_ bundle: Bundle = .main) -> APIClient? {
        guard let value = bundle.object(forInfoDictionaryKey: "WorkerBaseURL") as? String,
              !value.isEmpty,
              let url = URL(string: value) else { return nil }
        return APIClient(baseURL: url)
    }

    public func url(for endpoint: Endpoint) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        switch endpoint {
        case .top:
            components.path = basePath + "/v1/top"
        case .topSeries:
            components.path = basePath + "/v1/top/series"
        case .stats:
            components.path = basePath + "/v1/stats"
        case .rising(let window):
            components.path = basePath + "/v1/rising"
            components.queryItems = [URLQueryItem(name: "window", value: window.rawValue)]
        case .server(let id, let range):
            components.path = basePath + "/v1/server/" + id
            components.queryItems = [URLQueryItem(name: "range", value: range.rawValue)]
        }
        return components.url!
    }

    public func fetchData(_ endpoint: Endpoint) async throws -> Data {
        var request = URLRequest(url: url(for: endpoint))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport("not an HTTP response") }
        if http.statusCode == 503 { throw APIError.noData }
        guard http.statusCode == 200 else { throw APIError.http(status: http.statusCode) }
        return data
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}
