import Foundation
import CoreLocation

struct RecentSearch: Identifiable, Codable, Equatable {
    let id: UUID
    let label: String
    let location: StoredLocation
    let openedAt: Date
}

protocol RecentSearchStoring {
    func loadAll() -> [RecentSearch]
    func record(_ search: RecentSearch)
}

final class JSONRecentSearchStore: RecentSearchStoring {
    private let fileURL: URL
    private let maxCount: Int

    init(fileURL: URL = JSONRecentSearchStore.defaultFileURL(), maxCount: Int = 5) {
        self.fileURL = fileURL
        self.maxCount = maxCount
    }

    static func defaultFileURL() -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("recent_searches.json")
    }

    func loadAll() -> [RecentSearch] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([RecentSearch].self, from: data)) ?? []
    }

    func record(_ search: RecentSearch) {
        var all = loadAll()
        all.removeAll { $0.label == search.label }
        all.insert(search, at: 0)
        if all.count > maxCount {
            all = Array(all.prefix(maxCount))
        }
        guard let data = try? JSONEncoder().encode(all) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
