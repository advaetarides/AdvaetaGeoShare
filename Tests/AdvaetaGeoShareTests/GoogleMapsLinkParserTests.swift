import XCTest
import CoreLocation
@testable import AdvaetaGeoShare

final class GoogleMapsLinkParserTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.stubs = [:]
        super.tearDown()
    }

    func testViewportCoordinatePattern() async {
        let parser = GoogleMapsLinkParser()
        let result = await parser.parse("https://www.google.com/maps/@37.7749,-122.4194,15z")

        switch result {
        case .success(let coordinate):
            XCTAssertEqual(coordinate.latitude, 37.7749, accuracy: 0.0001)
            XCTAssertEqual(coordinate.longitude, -122.4194, accuracy: 0.0001)
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    func testNotAMapsLinkReturnsError() async {
        let parser = GoogleMapsLinkParser()
        let result = await parser.parse("just some random text with no link")

        switch result {
        case .failure(.notAMapsLink):
            break
        default:
            XCTFail("Expected .notAMapsLink, got \(result)")
        }
    }

    func testPrecisePinPatternTakesPriorityOverViewport() async {
        let parser = GoogleMapsLinkParser()
        let input = "https://www.google.com/maps/place/Eiffel+Tower/@48.8583,2.2945,17z/data=!4m5!3m4!1s0x0:0x0!8m2!3d48.8584600!4d2.2945000"
        let result = await parser.parse(input)

        switch result {
        case .success(let coordinate):
            XCTAssertEqual(coordinate.latitude, 48.8584600, accuracy: 0.0001)
            XCTAssertEqual(coordinate.longitude, 2.2945000, accuracy: 0.0001)
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    func testQueryParamPattern() async {
        let parser = GoogleMapsLinkParser()
        let result = await parser.parse("https://maps.google.com/maps?q=51.5074,-0.1278")

        switch result {
        case .success(let coordinate):
            XCTAssertEqual(coordinate.latitude, 51.5074, accuracy: 0.0001)
            XCTAssertEqual(coordinate.longitude, -0.1278, accuracy: 0.0001)
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    func testMapsLinkWithNoCoordinatesReturnsError() async {
        let parser = GoogleMapsLinkParser()
        let result = await parser.parse("https://www.google.com/maps/search/coffee+near+me")

        switch result {
        case .failure(.noCoordinatesFound):
            break
        default:
            XCTFail("Expected .noCoordinatesFound, got \(result)")
        }
    }

    func testShortLinkFollowsRedirectChain() async {
        let shortURL = URL(string: "https://maps.app.goo.gl/abc123")!
        let intermediateURL = URL(string: "https://www.google.com/maps/redirect/xyz")!
        let finalURL = URL(string: "https://www.google.com/maps/@40.7128,-74.0060,15z")!

        MockURLProtocol.stubs = [
            shortURL: .init(statusCode: 302, headers: ["Location": intermediateURL.absoluteString]),
            intermediateURL: .init(statusCode: 302, headers: ["Location": finalURL.absoluteString]),
            finalURL: .init(statusCode: 200, headers: [:]),
        ]

        let parser = GoogleMapsLinkParser(session: MockURLProtocol.mockedSession())
        let result = await parser.parse(shortURL.absoluteString)

        switch result {
        case .success(let coordinate):
            XCTAssertEqual(coordinate.latitude, 40.7128, accuracy: 0.0001)
            XCTAssertEqual(coordinate.longitude, -74.0060, accuracy: 0.0001)
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    func testShortLinkNetworkFailureReturnsNetworkError() async {
        let shortURL = URL(string: "https://maps.app.goo.gl/willfail")!
        // No stub registered — MockURLProtocol fails the request.
        let parser = GoogleMapsLinkParser(session: MockURLProtocol.mockedSession())
        let result = await parser.parse(shortURL.absoluteString)

        switch result {
        case .failure(.networkError):
            break
        default:
            XCTFail("Expected .networkError, got \(result)")
        }
    }
}
