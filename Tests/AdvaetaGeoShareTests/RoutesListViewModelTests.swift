import XCTest
import CoreLocation
@testable import AdvaetaGeoShare

private final class MockLauncher: OsmAndOpening {
    var result: LaunchResult = .opened
    var openedLocation: ParsedLocation?
    var openedStartNavigation: Bool?

    func open(_ location: ParsedLocation, startNavigation: Bool) async -> LaunchResult {
        openedLocation = location
        openedStartNavigation = startNavigation
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
        let viewModel = RoutesListViewModel(routeStore: store, launcher: MockLauncher(), filter: .points)

        viewModel.loadRoutes()

        XCTAssertEqual(viewModel.routes.map(\.name), ["Newer", "Older"])
    }

    func testLoadRoutesFiltersToPointsOnly() {
        let store = MockRouteStore()
        let point = SavedRoute(id: UUID(), name: "Point", location: .point(StoredCoordinate(latitude: 1, longitude: 1)), savedAt: Date())
        let route = SavedRoute(id: UUID(), name: "Route", location: .route(stops: [StoredCoordinate(latitude: 1, longitude: 1), StoredCoordinate(latitude: 2, longitude: 2)]), savedAt: Date())
        store.save(point)
        store.save(route)
        let viewModel = RoutesListViewModel(routeStore: store, launcher: MockLauncher(), filter: .points)

        viewModel.loadRoutes()

        XCTAssertEqual(viewModel.routes.map(\.name), ["Point"])
    }

    func testLoadRoutesFiltersToRoutesOnly() {
        let store = MockRouteStore()
        let point = SavedRoute(id: UUID(), name: "Point", location: .point(StoredCoordinate(latitude: 1, longitude: 1)), savedAt: Date())
        let route = SavedRoute(id: UUID(), name: "Route", location: .route(stops: [StoredCoordinate(latitude: 1, longitude: 1), StoredCoordinate(latitude: 2, longitude: 2)]), savedAt: Date())
        store.save(point)
        store.save(route)
        let viewModel = RoutesListViewModel(routeStore: store, launcher: MockLauncher(), filter: .routes)

        viewModel.loadRoutes()

        XCTAssertEqual(viewModel.routes.map(\.name), ["Route"])
    }

    func testDeleteRemovesRouteAndReloads() {
        let store = MockRouteStore()
        let route = SavedRoute(id: UUID(), name: "ToDelete", location: .point(StoredCoordinate(latitude: 1, longitude: 1)), savedAt: Date())
        store.save(route)
        let viewModel = RoutesListViewModel(routeStore: store, launcher: MockLauncher(), filter: .points)
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
        let viewModel = RoutesListViewModel(routeStore: store, launcher: launcher, filter: .routes)

        let result = await viewModel.open(route)

        XCTAssertEqual(result, .opened)
        switch launcher.openedLocation {
        case .route(let stops):
            XCTAssertEqual(stops.count, 2)
        default:
            XCTFail("Expected the route's stops to be passed to the launcher")
        }
    }

    func testOpenPassesTheRoutesStartNavigationPreferenceToTheLauncher() async {
        let store = MockRouteStore()
        let launcher = MockLauncher()
        let route = SavedRoute(
            id: UUID(),
            name: "Home",
            location: .point(StoredCoordinate(latitude: 1, longitude: 2)),
            savedAt: Date(),
            startNavigationByDefault: true
        )
        let viewModel = RoutesListViewModel(routeStore: store, launcher: launcher, filter: .points)

        _ = await viewModel.open(route)

        XCTAssertEqual(launcher.openedStartNavigation, true)
    }
}
