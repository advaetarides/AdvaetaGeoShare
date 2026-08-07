import XCTest
import CoreLocation
@testable import AdvaetaGeoShare

private final class MockURLOpener: URLOpening {
    var canOpenResult = true
    var openedURL: URL?

    func canOpen(_ url: URL) -> Bool {
        canOpenResult
    }

    func open(_ url: URL) async -> Bool {
        openedURL = url
        return true
    }
}

final class MapAppLauncherTests: XCTestCase {

    func testOpensOsmAndWithCorrectURLForASinglePoint() async throws {
        let opener = MockURLOpener()
        opener.canOpenResult = true
        let launcher = MapAppLauncher(urlOpener: opener)
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let result = await launcher.open(.point(coordinate), in: .osmAnd, startNavigation: false)

        XCTAssertEqual(result, .opened)
        let openedURL = try XCTUnwrap(opener.openedURL)
        XCTAssertEqual(openedURL.scheme, "osmandmaps")
        XCTAssertNotEqual(openedURL.host, "navigate")
        XCTAssertTrue(openedURL.query?.contains("lat=37.7749") ?? false)
        XCTAssertTrue(openedURL.query?.contains("lon=-122.4194") ?? false)
    }

    func testOpensOsmAndWithNavigateURLWhenStartNavigationIsTrue() async throws {
        let opener = MockURLOpener()
        opener.canOpenResult = true
        let launcher = MapAppLauncher(urlOpener: opener)
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let result = await launcher.open(.point(coordinate), in: .osmAnd, startNavigation: true)

        XCTAssertEqual(result, .opened)
        let openedURL = try XCTUnwrap(opener.openedURL)
        XCTAssertEqual(openedURL.scheme, "osmandmaps")
        XCTAssertEqual(openedURL.host, "navigate")
        XCTAssertTrue(openedURL.query?.contains("lat=37.7749") ?? false)
        XCTAssertTrue(openedURL.query?.contains("lon=-122.4194") ?? false)
    }

    func testOpensOsmAndWithRouteForMultipleStops() async throws {
        let opener = MockURLOpener()
        opener.canOpenResult = true
        let launcher = MapAppLauncher(urlOpener: opener)
        let stops = [
            CLLocationCoordinate2D(latitude: 53.4329149, longitude: -1.8689130),
            CLLocationCoordinate2D(latitude: 53.2767083, longitude: -1.7293244),
            CLLocationCoordinate2D(latitude: 53.3414465, longitude: -1.8008441),
        ]

        let result = await launcher.open(.route(stops: stops), in: .osmAnd, startNavigation: false)

        XCTAssertEqual(result, .opened)
        let openedURL = try XCTUnwrap(opener.openedURL)
        XCTAssertEqual(openedURL.scheme, "https")
        XCTAssertEqual(openedURL.host, "osmand.net")
        XCTAssertEqual(openedURL.path, "/map")
        let query = try XCTUnwrap(openedURL.query)
        XCTAssertTrue(query.contains("start=53.4329149,-1.868913"))
        XCTAssertTrue(query.contains("end=53.3414465,-1.8008441"))
        XCTAssertTrue(query.contains("via=53.2767083,-1.7293244"))
    }

    func testOpensGoogleMapsSearchForASinglePointWithoutNavigation() async throws {
        let opener = MockURLOpener()
        let launcher = MapAppLauncher(urlOpener: opener)
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let result = await launcher.open(.point(coordinate), in: .googleMaps, startNavigation: false)

        XCTAssertEqual(result, .opened)
        let openedURL = try XCTUnwrap(opener.openedURL)
        XCTAssertEqual(openedURL.scheme, "https")
        XCTAssertEqual(openedURL.host, "www.google.com")
        XCTAssertEqual(openedURL.path, "/maps/search")
        XCTAssertTrue(openedURL.query?.contains("query=37.7749,-122.4194") ?? false)
    }

    func testOpensGoogleMapsDirectionsForASinglePointWithNavigation() async throws {
        let opener = MockURLOpener()
        let launcher = MapAppLauncher(urlOpener: opener)
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let result = await launcher.open(.point(coordinate), in: .googleMaps, startNavigation: true)

        XCTAssertEqual(result, .opened)
        let openedURL = try XCTUnwrap(opener.openedURL)
        XCTAssertEqual(openedURL.path, "/maps/dir")
        let query = try XCTUnwrap(openedURL.query)
        XCTAssertTrue(query.contains("destination=37.7749,-122.4194"))
        XCTAssertFalse(query.contains("origin="))
    }

    func testOpensGoogleMapsDirectionsWithWaypointsForARoute() async throws {
        let opener = MockURLOpener()
        let launcher = MapAppLauncher(urlOpener: opener)
        let stops = [
            CLLocationCoordinate2D(latitude: 1, longitude: 2),
            CLLocationCoordinate2D(latitude: 3, longitude: 4),
            CLLocationCoordinate2D(latitude: 5, longitude: 6),
        ]

        let result = await launcher.open(.route(stops: stops), in: .googleMaps, startNavigation: false)

        XCTAssertEqual(result, .opened)
        let openedURL = try XCTUnwrap(opener.openedURL)
        let query = try XCTUnwrap(openedURL.query)
        XCTAssertTrue(query.contains("origin=1.0,2.0"))
        XCTAssertTrue(query.contains("destination=5.0,6.0"))
        XCTAssertTrue(query.contains("waypoints=3.0,4.0"))
    }

    func testOpensWazeWithNavigateFlagForASinglePoint() async throws {
        let opener = MockURLOpener()
        let launcher = MapAppLauncher(urlOpener: opener)
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let result = await launcher.open(.point(coordinate), in: .waze, startNavigation: true)

        XCTAssertEqual(result, .opened)
        let openedURL = try XCTUnwrap(opener.openedURL)
        XCTAssertEqual(openedURL.scheme, "https")
        XCTAssertEqual(openedURL.host, "waze.com")
        XCTAssertEqual(openedURL.path, "/ul")
        let query = try XCTUnwrap(openedURL.query)
        XCTAssertTrue(query.contains("ll=37.7749,-122.4194"))
        XCTAssertTrue(query.contains("navigate=yes"))
    }

    func testWazeFallsBackToDestinationOnlyForARoute() async throws {
        let opener = MockURLOpener()
        let launcher = MapAppLauncher(urlOpener: opener)
        let stops = [
            CLLocationCoordinate2D(latitude: 1, longitude: 2),
            CLLocationCoordinate2D(latitude: 3, longitude: 4),
            CLLocationCoordinate2D(latitude: 5, longitude: 6),
        ]

        let result = await launcher.open(.route(stops: stops), in: .waze, startNavigation: false)

        XCTAssertEqual(result, .opened)
        let openedURL = try XCTUnwrap(opener.openedURL)
        let query = try XCTUnwrap(openedURL.query)
        XCTAssertTrue(query.contains("ll=5.0,6.0"))
        XCTAssertTrue(query.contains("navigate=no"))
    }

    func testReturnsNotAvailableWhenAppCannotOpenURL() async {
        let opener = MockURLOpener()
        opener.canOpenResult = false
        let launcher = MapAppLauncher(urlOpener: opener)

        let result = await launcher.open(.point(CLLocationCoordinate2D(latitude: 0, longitude: 0)), in: .osmAnd, startNavigation: false)

        XCTAssertEqual(result, .notAvailable)
        XCTAssertNil(opener.openedURL)
    }

    // Regression guard: canOpenURL silently returns false for any scheme not declared here,
    // which reads identically to "not installed" even when it is. This caught a real bug
    // where "geo-navigation" was added but never added to Info.plist. Google Maps and Waze
    // don't need an entry here at all since they're targeted via https:// Universal Links,
    // which never require an LSApplicationQueriesSchemes declaration.
    func testAppDeclaresTheSchemeOsmAndLauncherUses() {
        let schemes = Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String] ?? []
        XCTAssertTrue(schemes.contains("osmandmaps"), "osmandmaps must be declared in LSApplicationQueriesSchemes")
    }
}
