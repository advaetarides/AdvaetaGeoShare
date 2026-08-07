import Foundation
import Observation

@Observable
final class RoutesListViewModel {
    private(set) var routes: [SavedRoute] = []

    private let routeStore: RouteStoring
    private let launcher: OsmAndOpening

    init(routeStore: RouteStoring, launcher: OsmAndOpening) {
        self.routeStore = routeStore
        self.launcher = launcher
    }

    func loadRoutes() {
        routes = routeStore.loadAll().sorted { $0.savedAt > $1.savedAt }
    }

    func delete(_ route: SavedRoute) {
        routeStore.delete(id: route.id)
        loadRoutes()
    }

    func open(_ route: SavedRoute) async -> LaunchResult {
        await launcher.open(route.location.parsed)
    }
}
