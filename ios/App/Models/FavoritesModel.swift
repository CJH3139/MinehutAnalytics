import Foundation
import MinehutKit
import Observation

@MainActor @Observable
final class FavoritesModel {
    private(set) var collection: FavoriteCollection
    private let defaults: UserDefaults
    private static let key = "savedServers.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        collection = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(FavoriteCollection.self, from: $0) } ?? FavoriteCollection()
    }

    func toggle(id: String, name: String) {
        collection.toggle(id: id, name: name)
        if let data = try? JSONEncoder().encode(collection) { defaults.set(data, forKey: Self.key) }
    }
}
