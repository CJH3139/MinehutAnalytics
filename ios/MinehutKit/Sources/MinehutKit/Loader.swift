import Foundation

public enum Loaded<Value: Sendable>: Sendable {
    case fresh(Value)
    case cached(Value, APIError)
    case failed(APIError)

    public var value: Value? {
        switch self {
        case .fresh(let value), .cached(let value, _): return value
        case .failed: return nil
        }
    }

    public var error: APIError? {
        switch self {
        case .fresh: return nil
        case .cached(_, let error), .failed(let error): return error
        }
    }

    public var isOffline: Bool {
        if case .cached = self { return true }
        return false
    }
}

public struct Loader: Sendable {
    public let client: APIClient
    public let cache: ResponseCache

    public init(client: APIClient, cache: ResponseCache) {
        self.client = client
        self.cache = cache
    }

    public func cached<T: Decodable & Sendable>(_ type: T.Type, _ endpoint: APIClient.Endpoint) -> T? {
        guard let data = cache.load(key: endpoint.cacheKey) else { return nil }
        return try? APIClient.decode(type, from: data)
    }

    public func load<T: Decodable & Sendable>(_ type: T.Type, _ endpoint: APIClient.Endpoint) async -> Loaded<T> {
        do {
            let data = try await client.fetchData(endpoint)
            let value = try APIClient.decode(type, from: data)
            cache.save(data, key: endpoint.cacheKey)
            return .fresh(value)
        } catch {
            let apiError = (error as? APIError) ?? .transport(error.localizedDescription)
            if let saved = cached(type, endpoint) { return .cached(saved, apiError) }
            return .failed(apiError)
        }
    }
}
