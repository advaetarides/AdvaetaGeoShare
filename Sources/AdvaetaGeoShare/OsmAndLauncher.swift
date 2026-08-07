import Foundation
import UIKit
import CoreLocation

enum LaunchResult: Equatable {
    case opened
    case osmAndNotInstalled
}

protocol URLOpening {
    func canOpen(_ url: URL) -> Bool
    func open(_ url: URL) async -> Bool
}

extension UIApplication: URLOpening {
    func canOpen(_ url: URL) -> Bool {
        canOpenURL(url)
    }

    func open(_ url: URL) async -> Bool {
        await open(url, options: [:])
    }
}

protocol OsmAndOpening {
    func open(_ location: ParsedLocation) async -> LaunchResult
}

struct OsmAndLauncher: OsmAndOpening {
    private let urlOpener: URLOpening

    init(urlOpener: URLOpening) {
        self.urlOpener = urlOpener
    }

    func open(_ location: ParsedLocation) async -> LaunchResult {
        let url: URL?
        switch location {
        case .point(let coordinate):
            url = Self.pointURL(for: coordinate)
        case .route(let stops):
            url = Self.routeURL(for: stops)
        }

        guard let url, urlOpener.canOpen(url) else {
            return .osmAndNotInstalled
        }
        _ = await urlOpener.open(url)
        return .opened
    }

    private static func pointURL(for coordinate: CLLocationCoordinate2D) -> URL? {
        var components = URLComponents()
        components.scheme = "osmandmaps"
        components.host = ""  // forces "osmandmaps://" (empty authority) to match OsmAnd's documented URL format
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude)),
            URLQueryItem(name: "z", value: "15"),
        ]
        return components.url
    }

    private static func routeURL(for stops: [CLLocationCoordinate2D]) -> URL? {
        guard stops.count >= 2, let source = stops.first, let destination = stops.last else { return nil }
        let waypoints = stops.dropFirst().dropLast()

        var components = URLComponents()
        components.scheme = "geo-navigation"
        components.host = ""
        components.path = "/directions"
        var queryItems = [
            URLQueryItem(name: "source", value: Self.commaFormat(source)),
            URLQueryItem(name: "destination", value: Self.commaFormat(destination)),
        ]
        queryItems.append(contentsOf: waypoints.map { URLQueryItem(name: "waypoint", value: Self.commaFormat($0)) })
        components.queryItems = queryItems
        return components.url
    }

    private static func commaFormat(_ coordinate: CLLocationCoordinate2D) -> String {
        "\(coordinate.latitude),\(coordinate.longitude)"
    }
}
