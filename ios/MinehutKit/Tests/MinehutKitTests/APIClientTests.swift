import XCTest
@testable import MinehutKit

final class APIClientTests: XCTestCase {
    private let base = URL(string: "https://w.example.dev")!

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    private func client() -> APIClient { APIClient(baseURL: base, session: StubURLProtocol.session()) }

    func testBuildsURLs() {
        let c = APIClient(baseURL: base)
        XCTAssertEqual(c.url(for: .top).absoluteString, "https://w.example.dev/v1/top")
        XCTAssertEqual(c.url(for: .stats).absoluteString, "https://w.example.dev/v1/stats")
        XCTAssertEqual(c.url(for: .rising(.sixHours)).absoluteString, "https://w.example.dev/v1/rising?window=6h")
        XCTAssertEqual(c.url(for: .server(id: "aaa", range: .week)).absoluteString, "https://w.example.dev/v1/server/aaa?range=7d")
        let slashed = APIClient(baseURL: URL(string: "https://w.example.dev/")!)
        XCTAssertEqual(slashed.url(for: .top).absoluteString, "https://w.example.dev/v1/top")
    }

    func testCacheKeys() {
        XCTAssertEqual(APIClient.Endpoint.top.cacheKey, "top")
        XCTAssertEqual(APIClient.Endpoint.stats.cacheKey, "stats")
        XCTAssertEqual(APIClient.Endpoint.rising(.oneHour).cacheKey, "rising_1h")
        XCTAssertEqual(APIClient.Endpoint.server(id: "aaa", range: .month).cacheKey, "server_aaa_30d")
    }

    func testFetchesAndDecodes() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/top")
            return (200, Fixtures.data(Fixtures.top))
        }
        let data = try await client().fetchData(.top)
        let top = try APIClient.decode(TopResponse.self, from: data)
        XCTAssertEqual(top.servers.first?.name, "TechMines")
    }

    func testMaps503ToNoData() async {
        StubURLProtocol.handler = { _ in (503, Fixtures.data("{\"error\":\"no_data\"}")) }
        await assertThrows(.noData) { try await self.client().fetchData(.top) }
    }

    func testMapsOtherStatusToHTTP() async {
        StubURLProtocol.handler = { _ in (500, Data()) }
        await assertThrows(.http(status: 500)) { try await self.client().fetchData(.stats) }
    }

    func testMapsNetworkFailureToTransport() async {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await client().fetchData(.top)
            XCTFail("expected an error")
        } catch let error as APIError {
            guard case .transport = error else { return XCTFail("expected transport, got \(error)") }
        } catch {
            XCTFail("expected APIError, got \(error)")
        }
    }

    func testDecodeFailureIsDecodingError() {
        XCTAssertThrowsError(try APIClient.decode(TopResponse.self, from: Data("nope".utf8))) { error in
            XCTAssertEqual(error as? APIError, .decoding)
        }
    }

    func testFromBundleWithoutKeyIsNil() {
        XCTAssertNil(APIClient.fromBundle(.main))
    }

    private func assertThrows(
        _ expected: APIError,
        _ body: () async throws -> Data,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await body()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? APIError, expected, file: file, line: line)
        }
    }
}
