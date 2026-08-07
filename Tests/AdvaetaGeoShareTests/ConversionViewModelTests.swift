import XCTest
import CoreLocation
@testable import AdvaetaGeoShare

private struct MockParser: LinkParsing {
    let result: Result<CLLocationCoordinate2D, ParseError>
    func parse(_ input: String) async -> Result<CLLocationCoordinate2D, ParseError> {
        result
    }
}

private struct MockLauncher: OsmAndOpening {
    let result: LaunchResult
    func open(coordinate: CLLocationCoordinate2D) async -> LaunchResult {
        result
    }
}

final class ConversionViewModelTests: XCTestCase {

    func testSuccessfulConversionEndsInIdleState() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .success(CLLocationCoordinate2D(latitude: 1, longitude: 2))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testNotAMapsLinkShowsError() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .failure(.notAMapsLink)),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "not a link"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("That doesn't look like a Google Maps link."))
    }

    func testNoCoordinatesFoundShowsError() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .failure(.noCoordinatesFound)),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://www.google.com/maps/search/coffee"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("Couldn't find a location in that link."))
    }

    func testNetworkErrorShowsError() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .failure(.networkError("timed out"))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://maps.app.goo.gl/abc"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("Couldn't resolve that link. Check your connection and try again."))
    }

    func testOsmAndNotInstalledShowsError() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .success(CLLocationCoordinate2D(latitude: 1, longitude: 2))),
            launcher: MockLauncher(result: .osmAndNotInstalled)
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("OsmAnd isn't installed. Install it from the App Store to continue."))
    }
}
