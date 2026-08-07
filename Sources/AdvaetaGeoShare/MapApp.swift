import Foundation

enum MapApp: String, Codable, CaseIterable, Identifiable {
    case osmAnd
    case googleMaps
    case waze

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .osmAnd: return "OsmAnd"
        case .googleMaps: return "Google Maps"
        case .waze: return "Waze"
        }
    }
}
