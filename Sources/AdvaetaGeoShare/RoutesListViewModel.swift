import Foundation

enum SavedRouteFilter {
    case points
    case routes

    func matches(_ route: SavedRoute) -> Bool {
        switch (self, route.location) {
        case (.points, .point):
            return true
        case (.routes, .route):
            return true
        default:
            return false
        }
    }
}

final class RoutesListViewModel: ObservableObject {
    @Published private(set) var routes: [SavedRoute] = []

    private let routeStore: RouteStoring
    private let launcher: OsmAndOpening
    private let filter: SavedRouteFilter

    init(routeStore: RouteStoring, launcher: OsmAndOpening, filter: SavedRouteFilter) {
        self.routeStore = routeStore
        self.launcher = launcher
        self.filter = filter
    }

    func loadRoutes() {
        routes = routeStore.loadAll().filter(filter.matches).sorted { $0.savedAt > $1.savedAt }
    }

    func delete(_ route: SavedRoute) {
        routeStore.delete(id: route.id)
        loadRoutes()
    }

    func open(_ route: SavedRoute) async -> LaunchResult {
        await launcher.open(route.location.parsed, startNavigation: route.startNavigationByDefault)
    }
}
