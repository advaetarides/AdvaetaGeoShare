import Foundation
@testable import AdvaetaGeoShare

final class MockRouteStore: RouteStoring {
    private var routes: [SavedRoute] = []

    func loadAll() -> [SavedRoute] {
        routes
    }

    func save(_ route: SavedRoute) {
        routes.append(route)
    }

    func delete(id: UUID) {
        routes.removeAll { $0.id == id }
    }
}
