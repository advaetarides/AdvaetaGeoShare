import Foundation
import UIKit
import CoreLocation

enum LaunchResult: Equatable {
    case opened
    case notAvailable
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

protocol MapAppOpening {
    func open(_ location: ParsedLocation, in app: MapApp, startNavigation: Bool) async -> LaunchResult
}

/// Builds a deep link for each supported map app and hands it to `urlOpener`.
///
/// All three providers are targeted via their officially documented https:// Universal
/// Link formats rather than custom URL schemes wherever one is published. This matters:
/// a custom scheme can silently not be registered by the installed app version (this bit
/// us with OsmAnd's geo-navigation:// scheme, which only exists in unreleased source —
/// canOpenURL failed with a hard "no such scheme" error, OSStatus -10814), whereas an
/// https:// link's canOpenURL always succeeds (worst case it falls back to the website).
/// OsmAnd's own osmandmaps:// custom scheme is kept because it's verified working on a
/// real device and long-established, not newly added.
struct MapAppLauncher: MapAppOpening {
    private let urlOpener: URLOpening

    init(urlOpener: URLOpening) {
        self.urlOpener = urlOpener
    }

    func open(_ location: ParsedLocation, in app: MapApp, startNavigation: Bool) async -> LaunchResult {
        let url: URL?
        switch app {
        case .osmAnd:
            url = Self.osmAndURL(for: location, startNavigation: startNavigation)
        case .googleMaps:
            url = Self.googleMapsURL(for: location, startNavigation: startNavigation)
        case .waze:
            url = Self.wazeURL(for: location, startNavigation: startNavigation)
        }

        guard let url, urlOpener.canOpen(url) else {
            return .notAvailable
        }
        _ = await urlOpener.open(url)
        return .opened
    }

    // MARK: - OsmAnd

    private static func osmAndURL(for location: ParsedLocation, startNavigation: Bool) -> URL? {
        switch location {
        case .point(let coordinate):
            return startNavigation ? osmAndNavigateURL(coordinate) : osmAndPointURL(coordinate)
        case .route(let stops):
            return osmAndRouteURL(stops)
        }
    }

    private static func osmAndPointURL(_ coordinate: CLLocationCoordinate2D) -> URL? {
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
    // device's current location, per OsmAnd's kNavigateActionHost handling.
    private static func osmAndNavigateURL(_ coordinate: CLLocationCoordinate2D) -> URL? {
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

    private static func osmAndRouteURL(_ stops: [CLLocationCoordinate2D]) -> URL? {
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
            queryItems.append(URLQueryItem(name: "via", value: waypoints.map(Self.commaFormat).joined(separator: ";")))
        }
        components.queryItems = queryItems
        return components.url
    }

    // MARK: - Google Maps
    // https://developers.google.com/maps/documentation/urls/get-started — the "Universal
    // URL" format, designed to open the app if installed and fall back to the web otherwise.

    private static func googleMapsURL(for location: ParsedLocation, startNavigation: Bool) -> URL? {
        switch location {
        case .point(let coordinate):
            return startNavigation
                ? googleMapsDirectionsURL(destination: coordinate, origin: nil, waypoints: [])
                : googleMapsSearchURL(coordinate)
        case .route(let stops):
            guard stops.count >= 2, let origin = stops.first, let destination = stops.last else { return nil }
            let waypoints = Array(stops.dropFirst().dropLast())
            return googleMapsDirectionsURL(destination: destination, origin: origin, waypoints: waypoints)
        }
    }

    private static func googleMapsSearchURL(_ coordinate: CLLocationCoordinate2D) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/maps/search/"
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: Self.commaFormat(coordinate)),
        ]
        return components.url
    }

    private static func googleMapsDirectionsURL(
        destination: CLLocationCoordinate2D,
        origin: CLLocationCoordinate2D?,
        waypoints: [CLLocationCoordinate2D]
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/maps/dir/"
        var queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "destination", value: Self.commaFormat(destination)),
            URLQueryItem(name: "travelmode", value: "driving"),
        ]
        if let origin {
            queryItems.append(URLQueryItem(name: "origin", value: Self.commaFormat(origin)))
        }
        if !waypoints.isEmpty {
            queryItems.append(URLQueryItem(name: "waypoints", value: waypoints.map(Self.commaFormat).joined(separator: "|")))
        }
        components.queryItems = queryItems
        return components.url
    }

    // MARK: - Waze
    // https://waze.com/ul — Waze's official Universal Link. Waze's own URL scheme has no
    // concept of multi-stop routes, so a route falls back to just its destination.

    private static func wazeURL(for location: ParsedLocation, startNavigation: Bool) -> URL? {
        let coordinate: CLLocationCoordinate2D
        switch location {
        case .point(let point):
            coordinate = point
        case .route(let stops):
            guard let destination = stops.last else { return nil }
            coordinate = destination
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "waze.com"
        components.path = "/ul"
        components.queryItems = [
            URLQueryItem(name: "ll", value: Self.commaFormat(coordinate)),
            URLQueryItem(name: "navigate", value: startNavigation ? "yes" : "no"),
        ]
        return components.url
    }

    private static func commaFormat(_ coordinate: CLLocationCoordinate2D) -> String {
        "\(coordinate.latitude),\(coordinate.longitude)"
    }
}
