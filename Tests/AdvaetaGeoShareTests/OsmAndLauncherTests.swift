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

final class OsmAndLauncherTests: XCTestCase {

    func testOpensOsmAndWithCorrectURLForASinglePoint() async throws {
        let opener = MockURLOpener()
        opener.canOpenResult = true
        let launcher = OsmAndLauncher(urlOpener: opener)
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let result = await launcher.open(.point(coordinate), startNavigation: false)

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
        let launcher = OsmAndLauncher(urlOpener: opener)
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let result = await launcher.open(.point(coordinate), startNavigation: true)

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
        let launcher = OsmAndLauncher(urlOpener: opener)
        let stops = [
            CLLocationCoordinate2D(latitude: 53.4329149, longitude: -1.8689130),
            CLLocationCoordinate2D(latitude: 53.2767083, longitude: -1.7293244),
            CLLocationCoordinate2D(latitude: 53.3414465, longitude: -1.8008441),
        ]

        let result = await launcher.open(.route(stops: stops), startNavigation: false)

        XCTAssertEqual(result, .opened)
        let openedURL = try XCTUnwrap(opener.openedURL)
        XCTAssertEqual(openedURL.scheme, "geo-navigation")
        XCTAssertEqual(openedURL.path, "/directions")
        let query = try XCTUnwrap(openedURL.query)
        XCTAssertTrue(query.contains("source=53.4329149,-1.868913"))
        XCTAssertTrue(query.contains("destination=53.3414465,-1.8008441"))
        XCTAssertTrue(query.contains("waypoint=53.2767083,-1.7293244"))
    }

    func testReturnsNotInstalledWhenOsmAndCannotOpenURL() async {
        let opener = MockURLOpener()
        opener.canOpenResult = false
        let launcher = OsmAndLauncher(urlOpener: opener)

        let result = await launcher.open(.point(CLLocationCoordinate2D(latitude: 0, longitude: 0)), startNavigation: false)

        XCTAssertEqual(result, .osmAndNotInstalled)
        XCTAssertNil(opener.openedURL)
    }

    // Regression guard: canOpenURL silently returns false for any scheme not declared here,
    // which reads identically to "OsmAnd isn't installed" even when it is. This caught a real
    // bug where "geo-navigation" was added to OsmAndLauncher but never added to Info.plist.
    func testAppDeclaresBothSchemesOsmAndLauncherUses() {
        let schemes = Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String] ?? []
        XCTAssertTrue(schemes.contains("osmandmaps"), "osmandmaps must be declared in LSApplicationQueriesSchemes")
        XCTAssertTrue(schemes.contains("geo-navigation"), "geo-navigation must be declared in LSApplicationQueriesSchemes")
    }
}
