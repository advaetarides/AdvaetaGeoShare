import SwiftUI

struct RoutesListView: View {
    @StateObject private var viewModel: RoutesListViewModel
    @State private var openError: String?

    init(viewModel: RoutesListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color.backgroundBlack.ignoresSafeArea()

            if viewModel.routes.isEmpty {
                Text("No saved routes yet.")
                    .font(.body(18))
                    .foregroundStyle(Color.textMuted)
            } else {
                List {
                    ForEach(viewModel.routes) { route in
                        Button {
                            Task {
                                let result = await viewModel.open(route)
                                if result == .osmAndNotInstalled {
                                    openError = "OsmAnd isn't installed. Install it from the App Store to continue."
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(route.name)
                                    .font(.heading(16))
                                    .foregroundStyle(Color.textCream)
                                Text(subtitle(for: route))
                                    .font(.caption(15))
                                    .italic()
                                    .foregroundStyle(Color.textMuted)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.backgroundSoft)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            viewModel.delete(viewModel.routes[index])
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("My Routes")
        .toolbarBackground(Color.backgroundBlack, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { viewModel.loadRoutes() }
        .alert("Couldn't Open Route", isPresented: .constant(openError != nil), actions: {
            Button("OK") { openError = nil }
        }, message: {
            Text(openError ?? "")
        })
        .preferredColorScheme(.dark)
    }

    private func subtitle(for route: SavedRoute) -> String {
        let base: String
        switch route.location {
        case .point:
            base = "Single location"
        case .route(let stops):
            base = "\(stops.count)-stop route"
        }
        return route.startNavigationByDefault ? "\(base) · Auto-navigate" : base
    }
}
