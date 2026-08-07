import XCTest
@testable import AdvaetaGeoShare

final class RecentSearchStoreTests: XCTestCase {
    private var tempFileURL: URL!

    override func setUp() {
        super.setUp()
        tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_recent_searches_\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFileURL)
        super.tearDown()
    }

    func testRecordAndLoadRoundTripsASearch() {
        let store = JSONRecentSearchStore(fileURL: tempFileURL)
        let search = RecentSearch(id: UUID(), label: "Home", location: .point(StoredCoordinate(latitude: 1, longitude: 2)), openedAt: Date(timeIntervalSince1970: 1000), app: .osmAnd)

        store.record(search)

        XCTAssertEqual(store.loadAll(), [search])
    }

    func testLoadAllReturnsEmptyWhenNoFileExists() {
        let store = JSONRecentSearchStore(fileURL: tempFileURL)
        XCTAssertEqual(store.loadAll(), [])
    }

    func testRemoveDeletesOnlyTheMatchingSearch() {
        let store = JSONRecentSearchStore(fileURL: tempFileURL)
        let keep = RecentSearch(id: UUID(), label: "Keep", location: .point(StoredCoordinate(latitude: 1, longitude: 1)), openedAt: Date())
        let remove = RecentSearch(id: UUID(), label: "Remove", location: .point(StoredCoordinate(latitude: 2, longitude: 2)), openedAt: Date())
        store.record(keep)
        store.record(remove)

        store.remove(id: remove.id)

        XCTAssertEqual(store.loadAll(), [keep])
    }

    func testRecordCapsAtMaxCountAndDropsOldest() {
        let store = JSONRecentSearchStore(fileURL: tempFileURL, maxCount: 2)
        store.record(RecentSearch(id: UUID(), label: "First", location: .point(StoredCoordinate(latitude: 1, longitude: 1)), openedAt: Date()))
        store.record(RecentSearch(id: UUID(), label: "Second", location: .point(StoredCoordinate(latitude: 2, longitude: 2)), openedAt: Date()))
        store.record(RecentSearch(id: UUID(), label: "Third", location: .point(StoredCoordinate(latitude: 3, longitude: 3)), openedAt: Date()))

        let labels = store.loadAll().map(\.label)
        XCTAssertEqual(labels, ["Third", "Second"])
    }
}
