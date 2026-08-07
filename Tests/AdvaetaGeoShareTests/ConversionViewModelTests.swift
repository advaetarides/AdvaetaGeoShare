import XCTest
import CoreLocation
@testable import AdvaetaGeoShare

private struct MockParser: LinkParsing {
    let result: Result<ParsedLocation, ParseError>
    func parse(_ input: String) async -> Result<ParsedLocation, ParseError> {
        result
    }
}

private struct MockGeocoder: AddressGeocoding {
    let result: Result<CLLocationCoordinate2D, GeocodeError>
    func geocode(_ address: String) async -> Result<CLLocationCoordinate2D, GeocodeError> {
        result
    }
}

private struct MockLauncher: OsmAndOpening {
    let result: LaunchResult
    func open(_ location: ParsedLocation, startNavigation: Bool) async -> LaunchResult {
        result
    }
}

final class ConversionViewModelTests: XCTestCase {

    private func makeViewModel(
        parser: LinkParsing,
        geocoder: AddressGeocoding = MockGeocoder(result: .failure(.notFound)),
        launcher: OsmAndOpening,
        routeStore: RouteStoring = MockRouteStore()
    ) -> ConversionViewModel {
        ConversionViewModel(parser: parser, geocoder: geocoder, launcher: launcher, routeStore: routeStore)
    }

    func testSuccessfulConversionEndsInIdleState() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testSuccessfulRouteConversionEndsInIdleState() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.route(stops: [
                CLLocationCoordinate2D(latitude: 1, longitude: 2),
                CLLocationCoordinate2D(latitude: 3, longitude: 4),
            ]))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://www.google.com/maps/dir/A/B/data=..."

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testNotAMapsLinkFallsBackToGeocodingAndSucceeds() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .failure(.notAMapsLink)),
            geocoder: MockGeocoder(result: .success(CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "SW1A 1AA"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testNotAMapsLinkAndGeocodingFailureShowsCombinedError() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .failure(.notAMapsLink)),
            geocoder: MockGeocoder(result: .failure(.notFound)),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "gibberish"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("Couldn't find that as a map link or an address."))
    }

    func testNoCoordinatesFoundShowsErrorWithoutTryingGeocoding() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .failure(.noCoordinatesFound)),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://www.google.com/maps/search/coffee"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("Couldn't find a location in that link."))
    }

    func testNetworkErrorShowsError() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .failure(.networkError("timed out"))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://maps.app.goo.gl/abc"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("Couldn't resolve that link. Check your connection and try again."))
    }

    func testOsmAndNotInstalledShowsError() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .osmAndNotInstalled)
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.convert()

        XCTAssertEqual(viewModel.state, .error("OsmAnd isn't installed. Install it from the App Store to continue."))
    }

    func testSaveRouteTappedPromptsForNameOnSuccessfulParse() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.saveRouteTapped()

        XCTAssertEqual(viewModel.state, .promptingForRouteName)
        XCTAssertTrue(viewModel.pendingLocationIsPoint)
    }

    func testSaveRouteTappedForARouteDoesNotOfferStartNavigationToggle() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.route(stops: [
                CLLocationCoordinate2D(latitude: 1, longitude: 2),
                CLLocationCoordinate2D(latitude: 3, longitude: 4),
            ]))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://www.google.com/maps/dir/A/B/data=..."

        await viewModel.saveRouteTapped()

        XCTAssertFalse(viewModel.pendingLocationIsPoint)
    }

    func testSaveRouteTappedShowsErrorOnParseFailure() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .failure(.notAMapsLink)),
            geocoder: MockGeocoder(result: .failure(.notFound)),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "not a link"

        await viewModel.saveRouteTapped()

        XCTAssertEqual(viewModel.state, .error("Couldn't find that as a map link or an address."))
    }

    func testConfirmSavePersistsTheRouteWithStartNavigationPreferenceAndReturnsToIdle() async {
        let store = MockRouteStore()
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .opened),
            routeStore: store
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"
        await viewModel.saveRouteTapped()

        viewModel.confirmSave(name: "My Route", startNavigationByDefault: true)

        XCTAssertEqual(viewModel.state, .idle)
        let saved = store.loadAll()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.name, "My Route")
        XCTAssertEqual(saved.first?.location, .point(StoredCoordinate(latitude: 1, longitude: 2)))
        XCTAssertEqual(saved.first?.startNavigationByDefault, true)
    }

    func testConfirmSaveWithBlankNameUsesUntitledRoute() async {
        let store = MockRouteStore()
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .opened),
            routeStore: store
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"
        await viewModel.saveRouteTapped()

        viewModel.confirmSave(name: "   ", startNavigationByDefault: false)

        XCTAssertEqual(store.loadAll().first?.name, "Untitled Route")
    }

    func testCancelSaveDiscardsThePendingRouteAndReturnsToIdle() async {
        let store = MockRouteStore()
        let viewModel = makeViewModel(
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
