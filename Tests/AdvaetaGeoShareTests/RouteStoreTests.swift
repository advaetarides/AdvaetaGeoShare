import XCTest
@testable import AdvaetaGeoShare

final class RouteStoreTests: XCTestCase {
    private var tempFileURL: URL!

    override func setUp() {
        super.setUp()
        tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_routes_\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFileURL)
        super.tearDown()
    }

    func testSaveAndLoadRoundTripsAPoint() {
        let store = JSONRouteStore(fileURL: tempFileURL)
        let route = SavedRoute(
            id: UUID(),
            name: "Home",
            location: .point(StoredCoordinate(latitude: 1.5, longitude: 2.5)),
            savedAt: Date(timeIntervalSince1970: 1000)
        )

        store.save(route)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded, [route])
    }

    func testSaveAndLoadRoundTripsARoute() {
        let store = JSONRouteStore(fileURL: tempFileURL)
        let route = SavedRoute(
            id: UUID(),
            name: "Peak District Tour",
            location: .route(stops: [
                StoredCoordinate(latitude: 1, longitude: 2),
                StoredCoordinate(latitude: 3, longitude: 4),
            ]),
            savedAt: Date(timeIntervalSince1970: 2000)
        )

        store.save(route)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded, [route])
    }

    func testDeleteRemovesOnlyTheMatchingRoute() {
        let store = JSONRouteStore(fileURL: tempFileURL)
        let keep = SavedRoute(id: UUID(), name: "Keep", location: .point(StoredCoordinate(latitude: 1, longitude: 1)), savedAt: Date())
        let remove = SavedRoute(id: UUID(), name: "Remove", location: .point(StoredCoordinate(latitude: 2, longitude: 2)), savedAt: Date())
        store.save(keep)
        store.save(remove)

        store.delete(id: remove.id)

        XCTAssertEqual(store.loadAll(), [keep])
    }

    func testLoadAllReturnsEmptyWhenNoFileExists() {
        let store = JSONRouteStore(fileURL: tempFileURL)
        XCTAssertEqual(store.loadAll(), [])
    }

    func testImportRoutesMergesWithExistingRoutes() {
        let store = JSONRouteStore(fileURL: tempFileURL)
        let existing = SavedRoute(id: UUID(), name: "Existing", location: .point(StoredCoordinate(latitude: 1, longitude: 1)), savedAt: Date())
        store.save(existing)
        let imported = SavedRoute(id: UUID(), name: "Imported", location: .point(StoredCoordinate(latitude: 2, longitude: 2)), savedAt: Date())

        store.importRoutes([imported])

        let names = Set(store.loadAll().map(\.name))
        XCTAssertEqual(names, ["Existing", "Imported"])
    }

    func testImportRoutesOverwritesExistingEntryWithSameId() {
        let store = JSONRouteStore(fileURL: tempFileURL)
        let id = UUID()
        let original = SavedRoute(id: id, name: "Original Name", location: .point(StoredCoordinate(latitude: 1, longitude: 1)), savedAt: Date())
        store.save(original)
        let updated = SavedRoute(id: id, name: "Updated Name", location: .point(StoredCoordinate(latitude: 1, longitude: 1)), savedAt: Date())

        store.importRoutes([updated])

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Updated Name")
    }
}
