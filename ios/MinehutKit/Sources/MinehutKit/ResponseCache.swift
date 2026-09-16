import Foundation

public struct ResponseCache: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func standard() -> ResponseCache {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return ResponseCache(directory: caches.appendingPathComponent("MinehutAnalyticsResponses", isDirectory: true))
    }

    public func save(_ data: Data, key: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL(key), options: .atomic)
    }

    public func load(key: String) -> Data? {
        try? Data(contentsOf: fileURL(key))
    }

    private func fileURL(_ key: String) -> URL {
        directory.appendingPathComponent(key + ".json")
    }
}
