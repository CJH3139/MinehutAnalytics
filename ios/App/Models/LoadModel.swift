import Foundation
import MinehutKit
import Observation

enum AppEnvironment {
    static let loader: Loader? = APIClient.fromBundle().map { Loader(client: $0, cache: .standard()) }
}

@MainActor
@Observable
final class LoadModel<Value: Decodable & Sendable> {
    private(set) var value: Value?
    private(set) var isOffline = false
    private(set) var error: APIError?
    private(set) var isLoading = false

    @ObservationIgnored private let loader: Loader?
    @ObservationIgnored private var lastEndpoint: APIClient.Endpoint?
    @ObservationIgnored private var generation = 0

    init(loader: Loader? = AppEnvironment.loader) {
        self.loader = loader
    }

    func load(_ endpoint: APIClient.Endpoint) async {
        guard let loader else {
            error = .transport("This build has no Worker URL.")
            return
        }
        if endpoint != lastEndpoint {
            lastEndpoint = endpoint
            if let saved = loader.cached(Value.self, endpoint) { value = saved }
            error = nil
            isOffline = false
        }
        generation += 1
        let current = generation
        isLoading = true
        let result = await loader.load(Value.self, endpoint)
        guard current == generation else { return }
        isLoading = false
        if let fresh = result.value { value = fresh }
        isOffline = result.isOffline
        error = result.value == nil ? result.error : nil
    }
}
