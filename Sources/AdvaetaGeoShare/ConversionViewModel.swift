import Foundation
import Observation

@Observable
final class ConversionViewModel {
    enum State: Equatable {
        case idle
        case resolving
        case error(String)
        case promptingForRouteName
    }

    private(set) var state: State = .idle
    var inputText: String = ""

    private let parser: LinkParsing
    private let launcher: OsmAndOpening
    private let routeStore: RouteStoring
    private var pendingSaveLocation: ParsedLocation?

    init(parser: LinkParsing, launcher: OsmAndOpening, routeStore: RouteStoring) {
        self.parser = parser
        self.launcher = launcher
        self.routeStore = routeStore
    }

    func convert() async {
        state = .resolving
        switch await parser.parse(inputText) {
        case .success(let location):
            switch await launcher.open(location) {
            case .opened:
                state = .idle
            case .osmAndNotInstalled:
                state = .error("OsmAnd isn't installed. Install it from the App Store to continue.")
            }
        case .failure(let error):
            state = .error(Self.message(for: error))
        }
    }

    func saveRouteTapped() async {
        state = .resolving
        switch await parser.parse(inputText) {
        case .success(let location):
            pendingSaveLocation = location
            state = .promptingForRouteName
        case .failure(let error):
            state = .error(Self.message(for: error))
        }
    }

    func confirmSave(name: String) {
        guard let location = pendingSaveLocation else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let route = SavedRoute(
            id: UUID(),
            name: trimmedName.isEmpty ? "Untitled Route" : trimmedName,
            location: location.stored,
            savedAt: Date()
        )
        routeStore.save(route)
        pendingSaveLocation = nil
        state = .idle
    }

    func cancelSave() {
        pendingSaveLocation = nil
        state = .idle
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
