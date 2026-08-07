import SwiftUI

struct MenuView: View {
    let routeStore: RouteStoring
    let launcher: OsmAndOpening

    var body: some View {
        ZStack {
            Color.backgroundBlack.ignoresSafeArea()

            List {
                NavigationLink {
                    RoutesListView(
                        viewModel: RoutesListViewModel(routeStore: routeStore, launcher: launcher, filter: .points),
                        title: "My Places",
                        emptyMessage: "No saved places yet."
                    )
                } label: {
                    Text("My Places")
                        .font(.heading(16))
                        .foregroundStyle(Color.textCream)
                        .padding(.vertical, 6)
                }
                .listRowBackground(Color.backgroundSoft)

                NavigationLink {
                    RoutesListView(
                        viewModel: RoutesListViewModel(routeStore: routeStore, launcher: launcher, filter: .routes),
                        title: "My Routes",
                        emptyMessage: "No saved routes yet."
                    )
                } label: {
                    Text("My Routes")
                        .font(.heading(16))
                        .foregroundStyle(Color.textCream)
                        .padding(.vertical, 6)
                }
                .listRowBackground(Color.backgroundSoft)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Menu")
        .toolbarBackground(Color.backgroundBlack, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}
