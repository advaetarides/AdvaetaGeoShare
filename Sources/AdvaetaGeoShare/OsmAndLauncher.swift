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
    func open(coordinate: CLLocationCoordinate2D) async -> LaunchResult
}

struct OsmAndLauncher: OsmAndOpening {
    private let urlOpener: URLOpening

    init(urlOpener: URLOpening) {
        self.urlOpener = urlOpener
    }

    func open(coordinate: CLLocationCoordinate2D) async -> LaunchResult {
        var components = URLComponents()
        components.scheme = "osmandmaps"
        components.host = ""  // forces "osmandmaps://" (empty authority) to match OsmAnd's documented URL format
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude)),
            URLQueryItem(name: "z", value: "15"),
        ]

        guard let url = components.url, urlOpener.canOpen(url) else {
            return .osmAndNotInstalled
        }
        _ = await urlOpener.open(url)
        return .opened
    }
}
