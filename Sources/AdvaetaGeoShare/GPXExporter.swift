import Foundation
import CoreLocation

/// Builds a minimal, standard GPX 1.1 document from a resolved location — a single point
/// becomes a `<wpt>`, a multi-stop route becomes an ordered `<rte>` of `<rtept>` entries
/// (GPX's own "ordered waypoints for navigation" concept, which maps directly onto ours).
struct GPXExporter {
    static func gpxString(for location: ParsedLocation, name: String) -> String {
        let escapedName = escape(name)
        switch location {
        case .point(let coordinate):
            return """
            <?xml version="1.0" encoding="UTF-8"?>
            <gpx version="1.1" creator="AdvaetaGeoShare" xmlns="http://www.topografix.com/GPX/1/1">
              <wpt lat="\(coordinate.latitude)" lon="\(coordinate.longitude)">
                <name>\(escapedName)</name>
              </wpt>
            </gpx>

            """
        case .route(let stops):
            let points = stops.enumerated().map { index, coordinate in
                "    <rtept lat=\"\(coordinate.latitude)\" lon=\"\(coordinate.longitude)\"><name>\(escape("Stop \(index + 1)"))</name></rtept>"
            }.joined(separator: "\n")
            return """
            <?xml version="1.0" encoding="UTF-8"?>
            <gpx version="1.1" creator="AdvaetaGeoShare" xmlns="http://www.topografix.com/GPX/1/1">
              <rte>
                <name>\(escapedName)</name>
            \(points)
              </rte>
            </gpx>

            """
        }
    }

    static func writeTemporaryFile(for location: ParsedLocation, name: String) -> URL? {
        guard let data = gpxString(for: location, name: name).data(using: .utf8) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(sanitizedFileName(name) + ".gpx")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func sanitizedFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let filtered = String(name.unicodeScalars.filter { allowed.contains($0) })
        let trimmed = filtered.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "route" : String(trimmed.prefix(60))
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
