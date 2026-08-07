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

    func testOpensOsmAndWithCorrectURLWhenInstalled() async throws {
        let opener = MockURLOpener()
        opener.canOpenResult = true
        let launcher = OsmAndLauncher(urlOpener: opener)
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let result = await launcher.open(coordinate: coordinate)

        XCTAssertEqual(result, .opened)
        let openedURL = try XCTUnwrap(opener.openedURL)
        XCTAssertEqual(openedURL.scheme, "osmandmaps")
        XCTAssertTrue(openedURL.query?.contains("lat=37.7749") ?? false)
        XCTAssertTrue(openedURL.query?.contains("lon=-122.4194") ?? false)
    }

    func testReturnsNotInstalledWhenOsmAndCannotOpenURL() async {
        let opener = MockURLOpener()
        opener.canOpenResult = false
        let launcher = OsmAndLauncher(urlOpener: opener)
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)

        let result = await launcher.open(coordinate: coordinate)

        XCTAssertEqual(result, .osmAndNotInstalled)
        XCTAssertNil(opener.openedURL)
    }
}
