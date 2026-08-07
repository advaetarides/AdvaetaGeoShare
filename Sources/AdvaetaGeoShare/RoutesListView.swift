import SwiftUI

struct RoutesListView: View {
    @StateObject private var viewModel: RoutesListViewModel
    @State private var openError: String?
    let title: String
    let emptyMessage: String

    init(viewModel: RoutesListViewModel, title: String, emptyMessage: String) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.title = title
        self.emptyMessage = emptyMessage
    }

    var body: some View {
        ZStack {
            Color.backgroundBlack.ignoresSafeArea()

            if viewModel.routes.isEmpty {
                Text(emptyMessage)
                    .font(.body(18))
                    .foregroundStyle(Color.textMuted)
            } else {
                List {
                    ForEach(viewModel.routes) { route in
                        Button {
                            Task {
                                let result = await viewModel.open(route)
                                if result == .notAvailable {
                                    openError = "\(route.preferredApp.displayName) isn't installed. Install it from the App Store to continue."
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
        .navigationTitle(title)
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
        var parts: [String] = [route.preferredApp.displayName]
        if case .route(let stops) = route.location {
            parts.append("\(stops.count)-stop route")
        }
        if route.startNavigationByDefault {
            parts.append("Auto-navigate")
        }
        return parts.joined(separator: " · ")
    }
}
