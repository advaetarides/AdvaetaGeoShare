import Foundation
import Observation

@Observable
final class ConversionViewModel {
    enum State: Equatable {
        case idle
        case resolving
        case error(String)
    }

    private(set) var state: State = .idle
    var inputText: String = ""

    private let parser: LinkParsing
    private let launcher: OsmAndOpening

    init(parser: LinkParsing, launcher: OsmAndOpening) {
        self.parser = parser
        self.launcher = launcher
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
        case .failure(.notAMapsLink):
            state = .error("That doesn't look like a Google Maps link.")
        case .failure(.noCoordinatesFound):
            state = .error("Couldn't find a location in that link.")
        case .failure(.networkError):
            state = .error("Couldn't resolve that link. Check your connection and try again.")
        }
    }
}
