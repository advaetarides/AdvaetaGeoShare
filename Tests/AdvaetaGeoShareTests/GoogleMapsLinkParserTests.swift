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
        case .success(.point(let coordinate)):
            XCTAssertEqual(coordinate.latitude, 37.7749, accuracy: 0.0001)
            XCTAssertEqual(coordinate.longitude, -122.4194, accuracy: 0.0001)
        default:
            XCTFail("Expected a single point, got \(result)")
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
        case .success(.point(let coordinate)):
            XCTAssertEqual(coordinate.latitude, 48.8584600, accuracy: 0.0001)
            XCTAssertEqual(coordinate.longitude, 2.2945000, accuracy: 0.0001)
        default:
            XCTFail("Expected a single point, got \(result)")
        }
    }

    func testQueryParamPattern() async {
        let parser = GoogleMapsLinkParser()
        let result = await parser.parse("https://maps.google.com/maps?q=51.5074,-0.1278")

        switch result {
        case .success(.point(let coordinate)):
            XCTAssertEqual(coordinate.latitude, 51.5074, accuracy: 0.0001)
            XCTAssertEqual(coordinate.longitude, -0.1278, accuracy: 0.0001)
        default:
            XCTFail("Expected a single point, got \(result)")
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
        case .success(.point(let coordinate)):
            XCTAssertEqual(coordinate.latitude, 40.7128, accuracy: 0.0001)
            XCTAssertEqual(coordinate.longitude, -74.0060, accuracy: 0.0001)
        default:
            XCTFail("Expected a single point, got \(result)")
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

    func testShortLinkResolvingToADirectionsPageReturnsRoute() async {
        let shortURL = URL(string: "https://maps.app.goo.gl/routeShare123")!
        let finalURL = URL(string: "https://www.google.com/maps/dir/A/B/data=!4m10!4m9!1m5!1m1!19sABC!2m2!1d10.0!2d20.0!1m5!1m1!19sDEF!2m2!1d11.0!2d21.0")!

        MockURLProtocol.stubs = [
            shortURL: .init(statusCode: 302, headers: ["Location": finalURL.absoluteString]),
            finalURL: .init(statusCode: 200, headers: [:]),
        ]

        let parser = GoogleMapsLinkParser(session: MockURLProtocol.mockedSession())
        let result = await parser.parse(shortURL.absoluteString)

        switch result {
        case .success(.route(let stops)):
            XCTAssertEqual(stops.count, 2)
            XCTAssertEqual(stops[0].latitude, 20.0, accuracy: 0.0001)
            XCTAssertEqual(stops[1].latitude, 21.0, accuracy: 0.0001)
        default:
            XCTFail("Expected a short link resolving to a directions page to return a route, got \(result)")
        }
    }

    func testDirectionsLinkWithMultipleStopsReturnsRoute() async {
        let parser = GoogleMapsLinkParser()
        let input = "https://www.google.com/maps/dir/Snake+Pass+Summit,+Pennine+Way,+Sheffield,+United+Kingdom/The+Yondermann+Cafe,+A623,+Wardlow+Mires,+Buxton,+United+Kingdom/Winnats+Pass,+United+Kingdom/data=!4m20!4m19!1m5!1m1!19sChIJG3dQeDnNe0gRPe_IEQx8naM!2m2!1d-1.8689129999999998!2d53.4329149!1m5!1m1!19sChIJEVo7dygsekgRzQtrNQtVk1Q!2m2!1d-1.7293243999999999!2d53.276708299999996!1m5!1m1!19sChIJzVyHEg8tekgR8mYhzMcT-Mo!2m2!1d-1.8008441!2d53.341446499999996!3e0?entry=gemini&utm_source=gemini&utm_campaign=gem-default"

        let result = await parser.parse(input)

        switch result {
        case .success(.route(let stops)):
            XCTAssertEqual(stops.count, 3)
            XCTAssertEqual(stops[0].latitude, 53.4329149, accuracy: 0.0001)
            XCTAssertEqual(stops[0].longitude, -1.8689129999999998, accuracy: 0.0001)
            XCTAssertEqual(stops[1].latitude, 53.2767083, accuracy: 0.0001)
            XCTAssertEqual(stops[1].longitude, -1.7293244, accuracy: 0.0001)
            XCTAssertEqual(stops[2].latitude, 53.3414465, accuracy: 0.0001)
            XCTAssertEqual(stops[2].longitude, -1.8008441, accuracy: 0.0001)
        default:
            XCTFail("Expected a 3-stop route, got \(result)")
        }
    }

    func testTwoStopDirectionsLinkReturnsRoute() async {
        let parser = GoogleMapsLinkParser()
        let input = "https://www.google.com/maps/dir/A/B/data=!4m10!4m9!1m5!1m1!19sABC!2m2!1d10.0!2d20.0!1m5!1m1!19sDEF!2m2!1d11.0!2d21.0"

        let result = await parser.parse(input)

        switch result {
        case .success(.route(let stops)):
            XCTAssertEqual(stops.count, 2)
            XCTAssertEqual(stops[0].latitude, 20.0, accuracy: 0.0001)
            XCTAssertEqual(stops[1].latitude, 21.0, accuracy: 0.0001)
        default:
            XCTFail("Expected a 2-stop route, got \(result)")
        }
    }
}
