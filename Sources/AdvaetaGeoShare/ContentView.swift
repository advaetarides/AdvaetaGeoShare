import SwiftUI
import UIKit

struct ContentView: View {
    @State private var viewModel: ConversionViewModel
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

                TextField("Paste a Google Maps link or type an address/postcode", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button {
                        if let clipboardText = UIPasteboard.general.string {
                            viewModel.inputText = clipboardText
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        viewModel.inputText = ""
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isInputEmpty)
                }

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
            .sheet(
                isPresented: Binding(
                    get: { viewModel.state == .promptingForRouteName },
                    set: { isPresented in if !isPresented { viewModel.cancelSave() } }
                )
            ) {
                SaveRouteSheet(
                    showsStartNavigationToggle: viewModel.pendingLocationIsPoint,
                    onSave: { name, startNavigationByDefault in
                        viewModel.confirmSave(name: name, startNavigationByDefault: startNavigationByDefault)
                    },
                    onCancel: {
                        viewModel.cancelSave()
                    }
                )
            }
        }
    }

    private var isInputEmpty: Bool {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
