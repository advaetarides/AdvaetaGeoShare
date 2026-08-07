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
    func open(_ location: ParsedLocation, startNavigation: Bool) async -> LaunchResult
}

struct OsmAndLauncher: OsmAndOpening {
    private let urlOpener: URLOpening

    init(urlOpener: URLOpening) {
        self.urlOpener = urlOpener
    }

    func open(_ location: ParsedLocation, startNavigation: Bool) async -> LaunchResult {
        let url: URL?
        switch location {
        case .point(let coordinate):
            url = startNavigation ? Self.navigateURL(for: coordinate) : Self.pointURL(for: coordinate)
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

    // "navigate" host tells OsmAnd to start turn-by-turn guidance immediately from the
    // device's current location, per OsmAnd's kNavigateActionHost handling — the plain
    // pointURL() above only re-centers the map without starting navigation.
    private static func navigateURL(for coordinate: CLLocationCoordinate2D) -> URL? {
        var components = URLComponents()
        components.scheme = "osmandmaps"
        components.host = "navigate"
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude)),
            URLQueryItem(name: "z", value: "15"),
        ]
        return components.url
    }

    private static func routeURL(for stops: [CLLocationCoordinate2D]) -> URL? {
        // The geo-navigation:// scheme (checked via a real device: OSStatus -10814,
        // kLSApplicationNotFoundErr) isn't registered by shipped OsmAnd versions yet
        // (confirmed against 5.3.3). osmand.net/map is an older, established Universal
        // Link OsmAnd's app already handles for multi-point routes, and being https it
        // never hard-fails canOpenURL the way an unregistered custom scheme does.
        guard stops.count >= 2, let source = stops.first, let destination = stops.last else { return nil }
        let waypoints = stops.dropFirst().dropLast()

        var components = URLComponents()
        components.scheme = "https"
        components.host = "osmand.net"
        components.path = "/map"
        var queryItems = [
            URLQueryItem(name: "start", value: Self.commaFormat(source)),
            URLQueryItem(name: "end", value: Self.commaFormat(destination)),
        ]
        if !waypoints.isEmpty {
            let viaValue = waypoints.map { Self.commaFormat($0) }.joined(separator: ";")
            queryItems.append(URLQueryItem(name: "via", value: viaValue))
        }
        components.queryItems = queryItems
        return components.url
    }

    private static func commaFormat(_ coordinate: CLLocationCoordinate2D) -> String {
        "\(coordinate.latitude),\(coordinate.longitude)"
    }
}
