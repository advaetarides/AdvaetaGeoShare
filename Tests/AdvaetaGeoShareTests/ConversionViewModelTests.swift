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

private struct MockLauncher: MapAppOpening {
    let result: LaunchResult
    func open(_ location: ParsedLocation, in app: MapApp, startNavigation: Bool) async -> LaunchResult {
        result
    }
}

final class ConversionViewModelTests: XCTestCase {

    private func makeViewModel(
        parser: LinkParsing,
        geocoder: AddressGeocoding = MockGeocoder(result: .failure(.notFound)),
        launcher: MapAppOpening,
        routeStore: RouteStoring = MockRouteStore(),
        recentSearchStore: RecentSearchStoring = MockRecentSearchStore()
    ) -> ConversionViewModel {
        ConversionViewModel(
            parser: parser,
            geocoder: geocoder,
            launcher: launcher,
            routeStore: routeStore,
            recentSearchStore: recentSearchStore
        )
    }

    func testSuccessfulConversionEndsInIdleState() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.convert(in: .osmAnd)

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

        await viewModel.convert(in: .osmAnd)

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testNotAMapsLinkFallsBackToGeocodingAndSucceeds() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .failure(.notAMapsLink)),
            geocoder: MockGeocoder(result: .success(CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "SW1A 1AA"

        await viewModel.convert(in: .osmAnd)

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testNotAMapsLinkAndGeocodingFailureShowsCombinedError() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .failure(.notAMapsLink)),
            geocoder: MockGeocoder(result: .failure(.notFound)),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "gibberish"

        await viewModel.convert(in: .osmAnd)

        XCTAssertEqual(viewModel.state, .error("Couldn't find that as a map link or an address."))
    }

    func testNoCoordinatesFoundShowsErrorWithoutTryingGeocoding() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .failure(.noCoordinatesFound)),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://www.google.com/maps/search/coffee"

        await viewModel.convert(in: .osmAnd)

        XCTAssertEqual(viewModel.state, .error("Couldn't find a location in that link."))
    }

    func testNetworkErrorShowsError() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .failure(.networkError("timed out"))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://maps.app.goo.gl/abc"

        await viewModel.convert(in: .osmAnd)

        XCTAssertEqual(viewModel.state, .error("Couldn't resolve that link. Check your connection and try again."))
    }

    func testAppNotAvailableShowsErrorNamingThatApp() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .notAvailable)
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.convert(in: .waze)

        XCTAssertEqual(viewModel.state, .error("Waze isn't installed. Install it from the App Store to continue."))
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
        XCTAssertEqual(viewModel.pendingLocationStopCount, 2)
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

        viewModel.confirmSave(name: "My Route", startNavigationByDefault: true, saveDestinationOnly: false, preferredApp: .googleMaps)

        XCTAssertEqual(viewModel.state, .idle)
        let saved = store.loadAll()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.name, "My Route")
        XCTAssertEqual(saved.first?.location, .point(StoredCoordinate(latitude: 1, longitude: 2)))
        XCTAssertEqual(saved.first?.startNavigationByDefault, true)
        XCTAssertEqual(saved.first?.preferredApp, .googleMaps)
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

        viewModel.confirmSave(name: "   ", startNavigationByDefault: false, saveDestinationOnly: false, preferredApp: .osmAnd)

        XCTAssertEqual(store.loadAll().first?.name, "Untitled Route")
    }

    func testConfirmSaveWithDestinationOnlySavesJustTheLastStopAsAPoint() async {
        let store = MockRouteStore()
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.route(stops: [
                CLLocationCoordinate2D(latitude: 1, longitude: 2),
                CLLocationCoordinate2D(latitude: 3, longitude: 4),
                CLLocationCoordinate2D(latitude: 5, longitude: 6),
            ]))),
            launcher: MockLauncher(result: .opened),
            routeStore: store
        )
        viewModel.inputText = "https://www.google.com/maps/dir/A/B/C/data=..."
        await viewModel.saveRouteTapped()

        viewModel.confirmSave(name: "Just the destination", startNavigationByDefault: true, saveDestinationOnly: true, preferredApp: .osmAnd)

        let saved = store.loadAll()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.location, .point(StoredCoordinate(latitude: 5, longitude: 6)))
        XCTAssertEqual(saved.first?.startNavigationByDefault, true)
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

    func testSuccessfulConversionRecordsARecentSearch() async {
        let recentSearchStore = MockRecentSearchStore()
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .opened),
            recentSearchStore: recentSearchStore
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.convert(in: .googleMaps)

        XCTAssertEqual(viewModel.recentSearches.count, 1)
        XCTAssertEqual(viewModel.recentSearches.first?.label, "https://www.google.com/maps/@1,2,15z")
        XCTAssertEqual(viewModel.recentSearches.first?.app, .googleMaps)
        XCTAssertEqual(recentSearchStore.loadAll().count, 1)
    }

    func testFailedConversionDoesNotRecordARecentSearch() async {
        let recentSearchStore = MockRecentSearchStore()
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .notAvailable),
            recentSearchStore: recentSearchStore
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.convert(in: .osmAnd)

        XCTAssertTrue(viewModel.recentSearches.isEmpty)
    }

    func testOpenRecentSearchOpensTheStoredLocationWithItsOwnApp() async {
        let recentSearchStore = MockRecentSearchStore()
        let search = RecentSearch(
            id: UUID(),
            label: "Somewhere",
            location: .point(StoredCoordinate(latitude: 5, longitude: 6)),
            openedAt: Date(),
            app: .waze
        )
        recentSearchStore.record(search)
        let viewModel = makeViewModel(
            parser: MockParser(result: .failure(.notAMapsLink)),
            launcher: MockLauncher(result: .opened),
            recentSearchStore: recentSearchStore
        )

        await viewModel.openRecentSearch(search)

        XCTAssertEqual(viewModel.state, .idle)
    }

    func testExportGPXTappedWritesAFileAndReturnsToIdle() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"

        await viewModel.exportGPXTapped()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertNotNil(viewModel.gpxExportURL)
        XCTAssertEqual(viewModel.gpxExportURL?.pathExtension, "gpx")
    }

    func testExportGPXTappedShowsErrorOnParseFailure() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .failure(.notAMapsLink)),
            geocoder: MockGeocoder(result: .failure(.notFound)),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "gibberish"

        await viewModel.exportGPXTapped()

        XCTAssertEqual(viewModel.state, .error("Couldn't find that as a map link or an address."))
        XCTAssertNil(viewModel.gpxExportURL)
    }

    func testClearGPXExportResetsTheURL() async {
        let viewModel = makeViewModel(
            parser: MockParser(result: .success(.point(CLLocationCoordinate2D(latitude: 1, longitude: 2)))),
            launcher: MockLauncher(result: .opened)
        )
        viewModel.inputText = "https://www.google.com/maps/@1,2,15z"
        await viewModel.exportGPXTapped()
        XCTAssertNotNil(viewModel.gpxExportURL)

        viewModel.clearGPXExport()

        XCTAssertNil(viewModel.gpxExportURL)
    }
}
