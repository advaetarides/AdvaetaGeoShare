import Foundation

protocol RouteStoring {
    func loadAll() -> [SavedRoute]
    func save(_ route: SavedRoute)
    func delete(id: UUID)
}

final class JSONRouteStore: RouteStoring {
    private let fileURL: URL

    init(fileURL: URL = JSONRouteStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    static func defaultFileURL() -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("saved_routes.json")
    }

    func loadAll() -> [SavedRoute] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([SavedRoute].self, from: data)) ?? []
    }

    func save(_ route: SavedRoute) {
        var routes = loadAll()
        routes.append(route)
        persist(routes)
    }

    func delete(id: UUID) {
        var routes = loadAll()
        routes.removeAll { $0.id == id }
        persist(routes)
    }

    private func persist(_ routes: [SavedRoute]) {
        guard let data = try? JSONEncoder().encode(routes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
