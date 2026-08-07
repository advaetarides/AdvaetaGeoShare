import SwiftUI

struct SaveRouteSheet: View {
    let stopCount: Int?
    let onSave: (String, Bool, Bool, MapApp) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var startNavigationByDefault: Bool = false
    @State private var saveDestinationOnly: Bool = false
    @State private var preferredApp: MapApp = .osmAnd

    private var isMultiStopRoute: Bool { stopCount != nil }
    private var showsStartNavigationToggle: Bool { !isMultiStopRoute || saveDestinationOnly }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundBlack.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    Text(isMultiStopRoute ? "Name This Route" : "Name This Place")
                        .font(.heading(20))
                        .tracking(1.5)
                        .foregroundStyle(Color.bronze)
                        .padding(.top, 24)

                    TextField(isMultiStopRoute ? "Route name" : "Place name", text: $name)
                        .goldFieldStyle()

                    Picker("Open with", selection: $preferredApp) {
                        ForEach(MapApp.allCases) { app in
                            Text(app.displayName).tag(app)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Color.bronze)

                    if let stopCount {
                        Toggle(isOn: $saveDestinationOnly) {
                            Text("Save destination only (not the \(stopCount)-stop route)")
                                .font(.body(17))
                                .foregroundStyle(Color.textCream)
                        }
                        .tint(Color.tealAccent)
                    }

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
                    Button("Save") { onSave(name, startNavigationByDefault, saveDestinationOnly, preferredApp) }
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
