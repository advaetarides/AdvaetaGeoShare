import Foundation
import CoreLocation

enum ParseError: Error, Equatable {
    case notAMapsLink
    case noCoordinatesFound
    case networkError(String)
}

protocol LinkParsing {
    func parse(_ input: String) async -> Result<CLLocationCoordinate2D, ParseError>
}

struct GoogleMapsLinkParser: LinkParsing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private static let shortLinkHosts: Set<String> = ["maps.app.goo.gl", "goo.gl", "g.co"]

    private static let pinCoordinateRegex = try! NSRegularExpression(
        pattern: #"!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)"#
    )
    private static let viewportCoordinateRegex = try! NSRegularExpression(
        pattern: #"@(-?\d+\.\d+),(-?\d+\.\d+)"#
    )
    private static let queryCoordinateRegex = try! NSRegularExpression(
        pattern: #"[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)"#
    )

    func parse(_ input: String) async -> Result<CLLocationCoordinate2D, ParseError> {
        guard let url = Self.extractURL(from: input) else {
            return .failure(.notAMapsLink)
        }

        let resolvedURLString: String
        if let host = url.host, Self.shortLinkHosts.contains(host) {
            switch await Self.resolveRedirect(for: url, session: session) {
            case .success(let resolved):
                resolvedURLString = resolved
            case .failure(let error):
                return .failure(error)
            }
        } else {
            resolvedURLString = url.absoluteString
        }

        if let coordinate = Self.extractCoordinate(from: resolvedURLString) {
            return .success(coordinate)
        }
        return .failure(.noCoordinatesFound)
    }

    private static func extractURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let matches = detector.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
        guard let match = matches.first,
              let range = Range(match.range, in: trimmed),
              let url = URL(string: String(trimmed[range])) else {
            return nil
        }
        guard let host = url.host,
              host.contains("google") || host.contains("goo.gl") || host == "g.co" else {
            return nil
        }
        return url
    }

    private static func resolveRedirect(for url: URL, session: URLSession, maxHops: Int = 5) async -> Result<String, ParseError> {
        var currentURL = url
        var hops = 0
        while hops < maxHops {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "HEAD"
            do {
                let (_, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    return .failure(.networkError("No HTTP response"))
                }
                if (300..<400).contains(httpResponse.statusCode),
                   let location = httpResponse.value(forHTTPHeaderField: "Location"),
                   let nextURL = URL(string: location, relativeTo: currentURL)?.absoluteURL {
                    currentURL = nextURL
                    hops += 1
                    continue
                }
                // Either the server returned a final response, or (on a real network
                // request, outside of tests) URLSession already auto-followed the
                // redirect chain — httpResponse.url reflects the true final URL either way.
                let finalURL = httpResponse.url ?? currentURL
                return .success(finalURL.absoluteString)
            } catch {
                return .failure(.networkError(error.localizedDescription))
            }
        }
        return .success(currentURL.absoluteString)
    }

    private static func extractCoordinate(from urlString: String) -> CLLocationCoordinate2D? {
        for regex in [pinCoordinateRegex, viewportCoordinateRegex, queryCoordinateRegex] {
            if let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
               let latRange = Range(match.range(at: 1), in: urlString),
               let lonRange = Range(match.range(at: 2), in: urlString),
               let lat = Double(urlString[latRange]),
               let lon = Double(urlString[lonRange]) {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        return nil
    }
}
