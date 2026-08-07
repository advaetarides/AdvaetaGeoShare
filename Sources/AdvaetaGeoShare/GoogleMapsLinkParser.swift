import Foundation
import CoreLocation

enum ParseError: Error, Equatable {
    case notAMapsLink
    case noCoordinatesFound
    case networkError(String)
}

enum ParsedLocation {
    case point(CLLocationCoordinate2D)
    case route(stops: [CLLocationCoordinate2D])
}

protocol LinkParsing {
    func parse(_ input: String) async -> Result<ParsedLocation, ParseError>
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
    // Directions links (/maps/dir/...) encode each stop as !1d<lng>!2d<lat> inside the data= param.
    private static let directionsStopRegex = try! NSRegularExpression(
        pattern: #"!1d(-?\d+\.\d+)!2d(-?\d+\.\d+)"#
    )

    func parse(_ input: String) async -> Result<ParsedLocation, ParseError> {
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

        if resolvedURLString.contains("/maps/dir/"),
           let stops = Self.extractDirectionsStops(from: resolvedURLString) {
            return .success(.route(stops: stops))
        }

        if let coordinate = Self.extractCoordinate(from: resolvedURLString) {
            return .success(.point(coordinate))
        }
        return .failure(.noCoordinatesFound)
    }

    private static func extractURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let matches = detector.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
        guard let match = matches.first, let range = Range(match.range, in: trimmed) else {
            return nil
        }

        // NSDataDetector's match range can truncate long, unusual-looking Google Maps URLs
        // (observed: it stops mid-way through directions links full of repeated "!1d..!2d.."
        // segments). A pasted link is expected to run to the end of the input, so extend from
        // the detected start to the end of the string rather than trusting the detector's own
        // end boundary. Also normalize a missing scheme (e.g. "google.com/maps/..." pasted
        // without "https://") since NSDataDetector's own scheme synthesis only covers its
        // (possibly truncated) match range.
        var candidate = String(trimmed[range.lowerBound...])
        if !candidate.lowercased().hasPrefix("http://") && !candidate.lowercased().hasPrefix("https://") {
            candidate = "https://" + candidate
        }

        guard let url = URL(string: candidate) else {
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

    private static func extractDirectionsStops(from urlString: String) -> [CLLocationCoordinate2D]? {
        let fullRange = NSRange(urlString.startIndex..., in: urlString)
        let matches = directionsStopRegex.matches(in: urlString, range: fullRange)

        var stops: [CLLocationCoordinate2D] = []
        for match in matches {
            guard let lonRange = Range(match.range(at: 1), in: urlString),
                  let latRange = Range(match.range(at: 2), in: urlString),
                  let lon = Double(urlString[lonRange]),
                  let lat = Double(urlString[latRange]) else { continue }
            stops.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        return stops.count >= 2 ? stops : nil
    }
}
