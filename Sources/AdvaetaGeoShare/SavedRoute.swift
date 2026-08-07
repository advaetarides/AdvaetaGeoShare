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
