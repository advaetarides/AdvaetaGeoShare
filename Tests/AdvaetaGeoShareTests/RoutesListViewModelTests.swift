import XCTest
import CoreLocation
@testable import AdvaetaGeoShare

private final class MockLauncher: OsmAndOpening {
    var result: LaunchResult = .opened
    var openedLocation: ParsedLocation?

    func open(_ location: ParsedLocation) async -> LaunchResult {
        openedLocation = location
        return result
    }
}

final class RoutesListViewModelTests: XCTestCase {

    func testLoadRoutesReturnsStoredRoutesNewestFirst() {
        let store = MockRouteStore()
        let older = SavedRoute(id: UUID(), name: "Older", location: .point(StoredCoordinate(latitude: 1, longitude: 1)), savedAt: Date(timeIntervalSince1970: 1000))
        let newer = SavedRoute(id: UUID(), name: "Newer", location: .point(StoredCoordinate(latitude: 2, longitude: 2)), savedAt: Date(timeIntervalSince1970: 2000))
        store.save(older)
        store.save(newer)
        let viewModel = RoutesListViewModel(routeStore: store, launcher: MockLauncher())

        viewModel.loadRoutes()

        XCTAssertEqual(viewModel.routes.map(\.name), ["Newer", "Older"])
    }

    func testDeleteRemovesRouteAndReloads() {
        let store = MockRouteStore()
        let route = SavedRoute(id: UUID(), name: "ToDelete", location: .point(StoredCoordinate(latitude: 1, longitude: 1)), savedAt: Date())
        store.save(route)
        let viewModel = RoutesListViewModel(routeStore: store, launcher: MockLauncher())
        viewModel.loadRoutes()

        viewModel.delete(route)

        XCTAssertTrue(viewModel.routes.isEmpty)
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    func testOpenPassesTheRoutesLocationToTheLauncher() async {
        let store = MockRouteStore()
        let launcher = MockLauncher()
        let route = SavedRoute(
            id: UUID(),
            name: "Route",
            location: .route(stops: [StoredCoordinate(latitude: 1, longitude: 2), StoredCoordinate(latitude: 3, longitude: 4)]),
            savedAt: Date()
        )
        let viewModel = RoutesListViewModel(routeStore: store, launcher: launcher)

        let result = await viewModel.open(route)

        XCTAssertEqual(result, .opened)
        switch launcher.openedLocation {
        case .route(let stops):
            XCTAssertEqual(stops.count, 2)
        default:
            XCTFail("Expected the route's stops to be passed to the launcher")
        }
    }
}
