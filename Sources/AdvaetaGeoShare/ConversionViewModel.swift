import Foundation

final class ConversionViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case resolving
        case error(String)
        case promptingForRouteName
    }

    @Published private(set) var state: State = .idle
    @Published var inputText: String = ""

    private let parser: LinkParsing
    private let geocoder: AddressGeocoding
    private let launcher: OsmAndOpening
    private let routeStore: RouteStoring
    private var pendingSaveLocation: ParsedLocation?

    var pendingLocationIsPoint: Bool {
        if case .point = pendingSaveLocation { return true }
        return false
    }

    init(parser: LinkParsing, geocoder: AddressGeocoding, launcher: OsmAndOpening, routeStore: RouteStoring) {
        self.parser = parser
        self.geocoder = geocoder
        self.launcher = launcher
        self.routeStore = routeStore
    }

    func convert() async {
        state = .resolving
        switch await resolveLocation() {
        case .success(let location):
            switch await launcher.open(location, startNavigation: false) {
            case .opened:
                state = .idle
            case .osmAndNotInstalled:
                state = .error("OsmAnd isn't installed. Install it from the App Store to continue.")
            }
        case .failure(let failure):
            state = .error(failure.message)
        }
    }

    func saveRouteTapped() async {
        state = .resolving
        switch await resolveLocation() {
        case .success(let location):
            pendingSaveLocation = location
            state = .promptingForRouteName
        case .failure(let failure):
            state = .error(failure.message)
        }
    }

    func confirmSave(name: String, startNavigationByDefault: Bool) {
        guard let location = pendingSaveLocation else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let route = SavedRoute(
            id: UUID(),
            name: trimmedName.isEmpty ? "Untitled Route" : trimmedName,
            location: location.stored,
            savedAt: Date(),
            startNavigationByDefault: startNavigationByDefault
        )
        routeStore.save(route)
        pendingSaveLocation = nil
        state = .idle
    }

    func cancelSave() {
        pendingSaveLocation = nil
        state = .idle
    }

    // A link parse failure of .notAMapsLink means the text isn't a URL at all, so it's
    // worth trying as a free-typed address/postcode — the other parse failures mean it
    // WAS a Maps link but something else went wrong, which geocoding can't fix.
    private func resolveLocation() async -> Result<ParsedLocation, ResolutionFailure> {
        switch await parser.parse(inputText) {
        case .success(let location):
            return .success(location)
        case .failure(.notAMapsLink):
            switch await geocoder.geocode(inputText) {
            case .success(let coordinate):
                return .success(ParsedLocation.point(coordinate))
            case .failure:
                return .failure(ResolutionFailure(message: "Couldn't find that as a map link or an address."))
            }
        case .failure(let error):
            return .failure(ResolutionFailure(message: Self.message(for: error)))
        }
    }

    private static func message(for error: ParseError) -> String {
        switch error {
        case .notAMapsLink:
            return "That doesn't look like a Google Maps link."
        case .noCoordinatesFound:
            return "Couldn't find a location in that link."
        case .networkError:
            return "Couldn't resolve that link. Check your connection and try again."
        }
    }
}

private struct ResolutionFailure: Error {
    let message: String
}
