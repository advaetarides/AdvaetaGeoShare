import SwiftUI

struct RoutesListView: View {
    @State private var viewModel: RoutesListViewModel
    @State private var openError: String?

    init(viewModel: RoutesListViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            if viewModel.routes.isEmpty {
                Text("No saved routes yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(viewModel.routes) { route in
                Button {
                    Task {
                        let result = await viewModel.open(route)
                        if result == .osmAndNotInstalled {
                            openError = "OsmAnd isn't installed. Install it from the App Store to continue."
                        }
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(route.name)
                            .font(.headline)
                        Text(subtitle(for: route))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                for index in offsets {
                    viewModel.delete(viewModel.routes[index])
                }
            }
        }
        .navigationTitle("My Routes")
        .onAppear { viewModel.loadRoutes() }
        .alert("Couldn't Open Route", isPresented: .constant(openError != nil), actions: {
            Button("OK") { openError = nil }
        }, message: {
            Text(openError ?? "")
        })
    }

    private func subtitle(for route: SavedRoute) -> String {
        switch route.location {
        case .point:
            return "Single location"
        case .route(let stops):
            return "\(stops.count)-stop route"
        }
    }
}
