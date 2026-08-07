import SwiftUI

/// Thin wrapper so a plain file URL can be handed to the system share sheet and presented
/// immediately via `.sheet(isPresented:)`, rather than requiring a second tap the way
/// SwiftUI's `ShareLink` does when the item isn't ready until the first tap resolves it.
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
