import Foundation
import MapKit

final class AddressAutocompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    func updateQuery(_ query: String) {
        completer.queryFragment = query
    }

    func clear() {
        suggestions = []
        completer.queryFragment = ""
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}

extension MKLocalSearchCompletion {
    /// Title + subtitle combined into one address string suitable for geocoding —
    /// MKLocalSearchCompleter splits a result into a bolded title (e.g. street/place
    /// name) and a subtitle (city/region), neither of which alone is a full address.
    var fullAddress: String {
        subtitle.isEmpty ? title : "\(title), \(subtitle)"
    }
}
