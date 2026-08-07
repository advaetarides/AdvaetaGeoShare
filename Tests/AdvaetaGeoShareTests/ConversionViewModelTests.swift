import XCTest
import CoreLocation
@testable import AdvaetaGeoShare

private struct MockParser: LinkParsing {
    let result: Result<ParsedLocation, ParseError>
    func parse(_ input: String) async -> Result<ParsedLocation, ParseError> {
        result
    }
}

private struct MockLauncher: OsmAndOpening {
    let result: LaunchResult
    func open(_ location: ParsedLocation) async -> LaunchResult {
        result
    }
}

final class ConversionViewModelTests: XCTestCase {

    func testSuccessfulConversionEndsInIdleState() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .opened),
            routeStore: MockRouteStore()
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testSuccessfulRouteConversionEndsInIdleState() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .success(.route(stops: [
                CLLocationCoordinate2D(latitude: 1, longitude: 2),
                CLLocationCoordinate2D(latitude: 3, longitude: 4),
            ]))),
            launcher: MockLauncher(result: .opened),
            routeStore: MockRouteStore()
        )
        viewModel.inputText = "https://www.google.com/maps/dir/A/B/data=..."

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testNotAMapsLinkShowsError() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .failure(.notAMapsLink)),
            launcher: MockLauncher(result: .opened),
            routeStore: MockRouteStore()
        )
        viewModel.inputText = "not a link"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("That doesn't look like a Google Maps link."))
    }

    func testNoCoordinatesFoundShowsError() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .failure(.noCoordinatesFound)),
            launcher: MockLauncher(result: .opened),
            routeStore: MockRouteStore()
        )
        viewModel.inputText = "https://www.google.com/maps/search/coffee"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("Couldn't find a location in that link."))
    }

    func testNetworkErrorShowsError() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .failure(.networkError("timed out"))),
            launcher: MockLauncher(result: .opened),
            routeStore: MockRouteStore()
        )
        viewModel.inputText = "https://maps.app.goo.gl/abc"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("Couldn't resolve that link. Check your connection and try again."))
    }

    func testOsmAndNotInstalledShowsError() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .osmAndNotInstalled),
            routeStore: MockRouteStore()
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("OsmAnd isn't installed. Install it from the App Store to continue."))
    }

    func testSaveRouteTappedPromptsForNameOnSuccessfulParse() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .opened),
            routeStore: MockRouteStore()
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.saveRouteTapped()

        XCTAssertEqual(viewModel.state, .promptingForRouteName)
    }

    func testSaveRouteTappedShowsErrorOnParseFailure() async {
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .failure(.notAMapsLink)),
            launcher: MockLauncher(result: .opened),
            routeStore: MockRouteStore()
        )
        viewModel.inputText = "not a link"

        await viewModel.saveRouteTapped()

        XCTAssertEqual(viewModel.state, .error("That doesn't look like a Google Maps link."))
    }

    func testConfirmSavePersistsTheRouteAndReturnsToIdle() async {
        let store = MockRouteStore()
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .opened),
            routeStore: store
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"
        await viewModel.saveRouteTapped()

        viewModel.confirmSave(name: "My Route")

        XCTAssertEqual(viewModel.state, .idle)
        let saved = store.loadAll()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.name, "My Route")
        XCTAssertEqual(saved.first?.location, .point(StoredCoordinate(latitude: 1, longitude: 2)))
    }

    func testConfirmSaveWithBlankNameUsesUntitledRoute() async {
        let store = MockRouteStore()
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .opened),
            routeStore: store
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"
        await viewModel.saveRouteTapped()

        viewModel.confirmSave(name: "   ")

        XCTAssertEqual(store.loadAll().first?.name, "Untitled Route")
    }

    func testCancelSaveDiscardsThePendingRouteAndReturnsToIdle() async {
        let store = MockRouteStore()
        let viewModel = ConversionViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .opened),
            routeStore: store
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"
        await viewModel.saveRouteTapped()

        viewModel.cancelSave()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(store.loadAll().isEmpty)
    }
}
