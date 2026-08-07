import SwiftUI

struct ContentView: View {
    @State private var viewModel: ConversionViewModel
    @State private var routeName: String = ""
    private let routeStore: RouteStoring
    private let launcher: OsmAndOpening

    init(viewModel: ConversionViewModel, routeStore: RouteStoring, launcher: OsmAndOpening) {
        self.viewModel = viewModel
        self.routeStore = routeStore
        self.launcher = launcher
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("AdvaetaGeoShare")
                    .font(.title2)
                    .bold()

                TextField("Paste a Google Maps link", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button("Open in OsmAnd") {
                        Task {
                            await viewModel.convert()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isInputEmpty || viewModel.state == .resolving)

                    Button("Save") {
                        Task {
                            await viewModel.saveRouteTapped()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isInputEmpty || viewModel.state == .resolving)
                }

                switch viewModel.state {
                case .idle, .promptingForRouteName:
                    EmptyView()
                case .resolving:
                    ProgressView("Resolving location…")
                case .error(let message):
                    Text(message)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 40)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("My Routes") {
                        RoutesListView(viewModel: RoutesListViewModel(routeStore: routeStore, launcher: launcher))
                    }
                }
            }
            .alert(
                "Name This Route",
                isPresented: Binding(
                    get: { viewModel.state == .promptingForRouteName },
                    set: { isPresented in if !isPresented { viewModel.cancelSave() } }
                )
            ) {
                TextField("Route name", text: $routeName)
                Button("Save") {
                    viewModel.confirmSave(name: routeName)
                    routeName = ""
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelSave()
                    routeName = ""
                }
            }
        }
    }

    private var isInputEmpty: Bool {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
