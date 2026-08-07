import Foundation
@testable import AdvaetaGeoShare

final class MockRecentSearchStore: RecentSearchStoring {
    private var searches: [RecentSearch] = []

    func loadAll() -> [RecentSearch] {
        searches
    }

    func record(_ search: RecentSearch) {
        searches.removeAll { $0.label == search.label }
        searches.insert(search, at: 0)
    }
}
