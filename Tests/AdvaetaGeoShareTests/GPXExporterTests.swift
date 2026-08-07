import XCTest
import CoreLocation
@testable import AdvaetaGeoShare

final class GPXExporterTests: XCTestCase {

    func testGPXStringForAPointContainsAWaypointWithCoordinatesAndName() {
        let xml = GPXExporter.gpxString(for: .point(CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12)), name: "Home")

        XCTAssertTrue(xml.contains("<wpt lat=\"51.5\" lon=\"-0.12\">"))
        XCTAssertTrue(xml.contains("<name>Home</name>"))
        XCTAssertFalse(xml.contains("<rte>"))
    }

    func testGPXStringForARouteContainsOrderedRoutePointsWithStopNames() {
        let xml = GPXExporter.gpxString(
            for: .route(stops: [
                CLLocationCoordinate2D(latitude: 1, longitude: 2),
                CLLocationCoordinate2D(latitude: 3, longitude: 4),
            ]),
            name: "My Trip"
        )

        XCTAssertTrue(xml.contains("<rte>"))
        XCTAssertTrue(xml.contains("<name>My Trip</name>"))
        XCTAssertTrue(xml.contains("<rtept lat=\"1.0\" lon=\"2.0\"><name>Stop 1</name></rtept>"))
        XCTAssertTrue(xml.contains("<rtept lat=\"3.0\" lon=\"4.0\"><name>Stop 2</name></rtept>"))
        XCTAssertFalse(xml.contains("<wpt"))
    }

    func testGPXStringEscapesReservedXMLCharactersInTheName() {
        let xml = GPXExporter.gpxString(for: .point(CLLocationCoordinate2D(latitude: 1, longitude: 2)), name: "Mom & Dad's <Place>")

        XCTAssertTrue(xml.contains("Mom &amp; Dad&apos;s &lt;Place&gt;") || xml.contains("Mom &amp; Dad's &lt;Place&gt;"))
    }

    func testWriteTemporaryFileProducesAReadableGPXFileWithGPXExtension() {
        let url = GPXExporter.writeTemporaryFile(for: .point(CLLocationCoordinate2D(latitude: 1, longitude: 2)), name: "Test Route")

        XCTAssertNotNil(url)
        guard let url else { return }
        XCTAssertEqual(url.pathExtension, "gpx")
        let contents = try? String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(contents?.contains("<wpt") ?? false)
        try? FileManager.default.removeItem(at: url)
    }

    func testWriteTemporaryFileSanitizesUnsafeCharactersInTheFileName() {
        let url = GPXExporter.writeTemporaryFile(for: .point(CLLocationCoordinate2D(latitude: 1, longitude: 2)), name: "A/B: C?.gpx")

        XCTAssertNotNil(url)
        guard let url else { return }
        XCTAssertFalse(url.lastPathComponent.contains("/"))
        XCTAssertFalse(url.lastPathComponent.contains(":"))
        XCTAssertFalse(url.lastPathComponent.contains("?"))
        try? FileManager.default.removeItem(at: url)
    }

    func testWriteTemporaryFileFallsBackToRouteWhenNameIsBlank() {
        let url = GPXExporter.writeTemporaryFile(for: .point(CLLocationCoordinate2D(latitude: 1, longitude: 2)), name: "   ")

        XCTAssertEqual(url?.deletingPathExtension().lastPathComponent, "route")
        if let url { try? FileManager.default.removeItem(at: url) }
    }
}
