import SwiftUI

struct SaveRouteSheet: View {
    let showsStartNavigationToggle: Bool
    let onSave: (String, Bool) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var startNavigationByDefault: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Route name", text: $name)
                if showsStartNavigationToggle {
                    Toggle("Start navigating automatically", isOn: $startNavigationByDefault)
                }
            }
            .navigationTitle("Save Route")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(name, startNavigationByDefault) }
                }
            }
        }
    }
}
