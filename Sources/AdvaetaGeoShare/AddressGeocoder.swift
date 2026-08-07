import Foundation
import CoreLocation

enum GeocodeError: Error, Equatable {
    case notFound
    case serviceError(String)
}

protocol AddressGeocoding {
    func geocode(_ address: String) async -> Result<CLLocationCoordinate2D, GeocodeError>
}

struct CLGeocoderAddressGeocoder: AddressGeocoding {
    private let geocoder = CLGeocoder()

    func geocode(_ address: String) async -> Result<CLLocationCoordinate2D, GeocodeError> {
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            guard let coordinate = placemarks.first?.location?.coordinate else {
                return .failure(.notFound)
            }
            return .success(coordinate)
        } catch {
            return .failure(.serviceError(error.localizedDescription))
        }
    }
}
