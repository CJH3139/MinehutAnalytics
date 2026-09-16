import XCTest
@testable import MinehutKit

final class LoaderTests: XCTestCase {
    private var directory: URL!
    private var loader: Loader!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let client = APIClient(baseURL: URL(string: "https://w.example.dev")!, session: StubURLProtocol.session())
        loader = Loader(client: client, cache: ResponseCache(directory: directory))
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testFreshLoadIsSavedAndServedWhenOffline() async {
        StubURLProtocol.handler = { _ in (200, Fixtures.data(Fixtures.top)) }
        let first = await loader.load(TopResponse.self, .top)
        guard case .fresh(let top) = first else { return XCTFail("expected fresh, got \(first)") }
        XCTAssertEqual(top.servers.count, 2)
        XCTAssertFalse(first.isOffline)

        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let second = await loader.load(TopResponse.self, .top)
        XCTAssertTrue(second.isOffline)
        XCTAssertEqual(second.value, top)
        guard case .transport = second.error else { return XCTFail("expected transport error") }
    }

    func testFailsWithoutCache() async {
        StubURLProtocol.handler = { _ in (500, Data()) }
        let result = await loader.load(TopResponse.self, .top)
        XCTAssertNil(result.value)
        XCTAssertEqual(result.error, .http(status: 500))
    }

    func testNoDataWithoutCache() async {
        StubURLProtocol.handler = { _ in (503, Data()) }
        let result = await loader.load(TopResponse.self, .top)
        XCTAssertEqual(result.error, .noData)
    }

    func testCachedReadsOnlyDisk() async {
        XCTAssertNil(loader.cached(TopResponse.self, .top))
        StubURLProtocol.handler = { _ in (200, Fixtures.data(Fixtures.top)) }
        _ = await loader.load(TopResponse.self, .top)
        StubURLProtocol.handler = nil
        XCTAssertEqual(loader.cached(TopResponse.self, .top)?.servers.first?.id, "aaa")
        XCTAssertNil(loader.cached(TopResponse.self, .stats))
    }
}
