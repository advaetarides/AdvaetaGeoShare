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

        let result = await launcher.open(.point(coordinate))

        XCTAssertEqual(result, .opened)
        let openedURL = try XCTUnwrap(opener.openedURL)
        XCTAssertEqual(openedURL.scheme, "osmandmaps")
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

        let result = await launcher.open(.route(stops: stops))

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

        let result = await launcher.open(.point(CLLocationCoordinate2D(latitude: 0, longitude: 0)))

        XCTAssertEqual(result, .osmAndNotInstalled)
        XCTAssertNil(opener.openedURL)
    }
}
