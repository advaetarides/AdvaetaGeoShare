import SwiftUI

struct SaveRouteSheet: View {
    let showsStartNavigationToggle: Bool
    let onSave: (String, Bool) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var startNavigationByDefault: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundBlack.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    Text("Name This Route")
                        .font(.heading(20))
                        .tracking(1.5)
                        .foregroundStyle(Color.bronze)
                        .padding(.top, 24)

                    TextField("Route name", text: $name)
                        .goldFieldStyle()

                    if showsStartNavigationToggle {
                        Toggle(isOn: $startNavigationByDefault) {
                            Text("Start navigating automatically")
                                .font(.body(17))
                                .foregroundStyle(Color.textCream)
                        }
                        .tint(Color.tealAccent)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .font(.heading(13))
                        .tracking(1)
                        .foregroundStyle(Color.textMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(name, startNavigationByDefault) }
                        .font(.heading(13))
                        .tracking(1)
                        .foregroundStyle(Color.bronze)
                }
            }
            .toolbarBackground(Color.backgroundBlack, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}
