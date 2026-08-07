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
            ZStack {
                Color.backgroundBlack.ignoresSafeArea()

                VStack(spacing: 20) {
                    MedallionLogo(diameter: 96)
                        .padding(.top, 24)

                    Text("AdvaetaGeoShare")
                        .font(.display(30))
                        .foregroundStyle(Color.bronze)
                        .tracking(1)

                    Text("Paste a link. Find your way.")
                        .font(.caption(16))
                        .italic()
                        .foregroundStyle(Color.textMuted)

                    TextField("Paste a Google Maps link or type an address/postcode", text: $viewModel.inputText, axis: .vertical)
                        .goldFieldStyle()
                        .padding(.horizontal)
                        .padding(.top, 8)

                    HStack(spacing: 12) {
                        Button {
                            if let clipboardText = UIPasteboard.general.string {
                                viewModel.inputText = clipboardText
                            }
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(GoldOutlineButtonStyle(tint: .darkBrown, textColor: .textMuted))

                        Button {
                            viewModel.inputText = ""
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                        .buttonStyle(GoldOutlineButtonStyle(tint: .darkBrown, textColor: .textMuted))
                        .disabled(isInputEmpty)
                        .opacity(isInputEmpty ? 0.4 : 1)
                    }

                    HStack(spacing: 12) {
                        Button("Open in OsmAnd") {
                            Task {
                                await viewModel.convert()
                            }
                        }
                        .buttonStyle(GoldOutlineButtonStyle())
                        .disabled(isInputEmpty || viewModel.state == .resolving)
                        .opacity(isInputEmpty || viewModel.state == .resolving ? 0.4 : 1)

                        Button("Save") {
                            Task {
                                await viewModel.saveRouteTapped()
                            }
                        }
                        .buttonStyle(GoldOutlineButtonStyle(tint: .tealAccent, textColor: .tealLight))
                        .disabled(isInputEmpty || viewModel.state == .resolving)
                        .opacity(isInputEmpty || viewModel.state == .resolving ? 0.4 : 1)
                    }

                    switch viewModel.state {
                    case .idle, .promptingForRouteName:
                        EmptyView()
                    case .resolving:
                        ProgressView("Resolving location…")
                            .tint(Color.bronze)
                            .foregroundStyle(Color.textMuted)
                    case .error(let message):
                        Text(message)
                            .font(.caption(17))
                            .foregroundStyle(Color.bronzeBright)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.top, 20)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        RoutesListView(viewModel: RoutesListViewModel(routeStore: routeStore, launcher: launcher))
                    } label: {
                        Text("My Routes")
                            .font(.heading(13))
                            .tracking(1.5)
                            .foregroundStyle(Color.bronze)
                    }
                }
            }
            .toolbarBackground(Color.backgroundBlack, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
        .preferredColorScheme(.dark)
    }

    private var isInputEmpty: Bool {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
