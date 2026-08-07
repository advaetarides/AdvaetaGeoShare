import SwiftUI

@main
struct AdvaetaGeoShareApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: ConversionViewModel(
                    parser: GoogleMapsLinkParser(),
                    launcher: OsmAndLauncher(urlOpener: UIApplication.shared)
                )
            )
        }
    }
}
