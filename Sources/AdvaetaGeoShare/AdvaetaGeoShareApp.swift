import SwiftUI

@main
struct AdvaetaGeoShareApp: App {
    private let routeStore = JSONRouteStore()
    private let recentSearchStore = JSONRecentSearchStore()

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: ConversionViewModel(
                    parser: GoogleMapsLinkParser(),
                    geocoder: CLGeocoderAddressGeocoder(),
                    launcher: OsmAndLauncher(urlOpener: UIApplication.shared),
                    routeStore: routeStore,
                    recentSearchStore: recentSearchStore
                ),
                routeStore: routeStore,
                launcher: OsmAndLauncher(urlOpener: UIApplication.shared)
            )
        }
    }
}
