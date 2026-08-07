import SwiftUI

@main
struct AdvaetaGeoShareApp: App {
    private let routeStore = JSONRouteStore()

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: ConversionViewModel(
                    parser: GoogleMapsLinkParser(),
                    geocoder: CLGeocoderAddressGeocoder(),
                    launcher: OsmAndLauncher(urlOpener: UIApplication.shared),
                    routeStore: routeStore
                ),
                routeStore: routeStore,
                launcher: OsmAndLauncher(urlOpener: UIApplication.shared)
            )
        }
    }
}
