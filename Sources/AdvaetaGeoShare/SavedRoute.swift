import Foundation
import CoreLocation

struct StoredCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

enum StoredLocation: Codable, Equatable {
    case point(StoredCoordinate)
    case route(stops: [StoredCoordinate])
}

struct SavedRoute: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let location: StoredLocation
    let savedAt: Date
    var startNavigationByDefault: Bool

    init(id: UUID, name: String, location: StoredLocation, savedAt: Date, startNavigationByDefault: Bool = false) {
        self.id = id
        self.name = name
        self.location = location
        self.savedAt = savedAt
        self.startNavigationByDefault = startNavigationByDefault
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, location, savedAt, startNavigationByDefault
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        location = try container.decode(StoredLocation.self, forKey: .location)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        // Defaults to false so routes saved before this field existed still decode.
        startNavigationByDefault = try container.decodeIfPresent(Bool.self, forKey: .startNavigationByDefault) ?? false
    }
}

extension ParsedLocation {
    var stored: StoredLocation {
        switch self {
        case .point(let coordinate):
            return .point(StoredCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
        case .route(let stops):
            return .route(stops: stops.map { StoredCoordinate(latitude: $0.latitude, longitude: $0.longitude) })
        }
    }
}

extension StoredLocation {
    var parsed: ParsedLocation {
        switch self {
        case .point(let coordinate):
            return .point(CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude))
        case .route(let stops):
            return .route(stops: stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
        }
    }
}
