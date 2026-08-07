import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel: ConversionViewModel
    @StateObject private var autocompleter = AddressAutocompleter()
    @FocusState private var fieldIsFocused: Bool
    @State private var copiedSearchID: UUID?
    private let routeStore: RouteStoring
    private let launcher: MapAppOpening

    init(viewModel: ConversionViewModel, routeStore: RouteStoring, launcher: MapAppOpening) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.routeStore = routeStore
        self.launcher = launcher
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        MedallionLogo(diameter: 96)
                            .padding(.top, 24)

                        Text("GeoShare")
                            .font(.display(30))
                            .foregroundStyle(Color.bronze)
                            .tracking(1)

                        Text("Paste a link. Find your way.")
                            .font(.caption(16))
                            .italic()
                            .foregroundStyle(Color.textMuted)

                        TextField("Paste a Google Maps link or type an address/postcode", text: $viewModel.inputText, axis: .vertical)
                            .lineLimit(1...5)
                            .focused($fieldIsFocused)
                            .goldFieldStyle()
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .onChange(of: viewModel.inputText) { newValue in
                                if looksLikeURL(newValue) {
                                    autocompleter.clear()
                                } else {
                                    autocompleter.updateQuery(newValue)
                                }
                            }

                        if fieldIsFocused && !autocompleter.suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                let suggestions = autocompleter.suggestions
                                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                                    Button {
                                        viewModel.inputText = suggestion.fullAddress
                                        autocompleter.clear()
                                        fieldIsFocused = false
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.title)
                                                .font(.body(16))
                                                .foregroundStyle(Color.textCream)
                                            if !suggestion.subtitle.isEmpty {
                                                Text(suggestion.subtitle)
                                                    .font(.caption(14))
                                                    .foregroundStyle(Color.textMuted)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                    }
                                    .buttonStyle(.plain)

                                    if index != suggestions.count - 1 {
                                        Rectangle()
                                            .fill(Color.bronzeDim.opacity(0.2))
                                            .frame(height: 1)
                                    }
                                }
                            }
                            .background(Color.backgroundSoft)
                            .overlay(Rectangle().strokeBorder(Color.bronzeDim.opacity(0.5), lineWidth: 1))
                            .padding(.horizontal)
                        }

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
                            Menu {
                                ForEach(MapApp.allCases) { app in
                                    Button(app.displayName) {
                                        Task {
                                            await viewModel.convert(in: app)
                                        }
                                    }
                                }
                            } label: {
                                Text("Open In")
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

                        Button {
                            Task {
                                await viewModel.exportGPXTapped()
                            }
                        } label: {
                            Label("Export GPX", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(GoldOutlineButtonStyle(tint: .darkBrown, textColor: .textMuted))
                        .disabled(isInputEmpty || viewModel.state == .resolving)
                        .opacity(isInputEmpty || viewModel.state == .resolving ? 0.4 : 1)

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

                        if !viewModel.recentSearches.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent")
                                    .font(.heading(13))
                                    .tracking(1.5)
                                    .foregroundStyle(Color.textMuted)
                                    .padding(.horizontal)

                                VStack(spacing: 0) {
                                    let recents = viewModel.recentSearches
                                    ForEach(Array(recents.enumerated()), id: \.element.id) { index, search in
                                        HStack(spacing: 8) {
                                            Button {
                                                Task {
                                                    await viewModel.openRecentSearch(search)
                                                }
                                            } label: {
                                                Text(search.label)
                                                    .font(.caption(13))
                                                    .foregroundStyle(Color.textCream)
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(viewModel.state == .resolving)

                                            Button {
                                                UIPasteboard.general.string = search.label
                                                copiedSearchID = search.id
                                                Task {
                                                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                                                    if copiedSearchID == search.id {
                                                        copiedSearchID = nil
                                                    }
                                                }
                                            } label: {
                                                if copiedSearchID == search.id {
                                                    Text("Copied")
                                                        .font(.caption(11))
                                                        .foregroundStyle(Color.tealLight)
                                                } else {
                                                    Image(systemName: "doc.on.doc")
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(Color.textMuted)
                                                }
                                            }
                                            .buttonStyle(.plain)

                                            Button {
                                                viewModel.removeRecentSearch(search)
                                            } label: {
                                                Image(systemName: "xmark.circle")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color.textMuted)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)

                                        if index != recents.count - 1 {
                                            Rectangle()
                                                .fill(Color.bronzeDim.opacity(0.2))
                                                .frame(height: 1)
                                        }
                                    }
                                }
                                .background(Color.backgroundSoft)
                                .overlay(Rectangle().strokeBorder(Color.bronzeDim.opacity(0.5), lineWidth: 1))
                                .padding(.horizontal)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture {
                    fieldIsFocused = false
                    autocompleter.clear()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        MenuView(routeStore: routeStore, launcher: launcher)
                    } label: {
                        Image(systemName: "line.3.horizontal")
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
                    stopCount: viewModel.pendingLocationStopCount,
                    onSave: { name, startNavigationByDefault, saveDestinationOnly, preferredApp in
                        viewModel.confirmSave(
                            name: name,
                            startNavigationByDefault: startNavigationByDefault,
                            saveDestinationOnly: saveDestinationOnly,
                            preferredApp: preferredApp
                        )
                    },
                    onCancel: {
                        viewModel.cancelSave()
                    }
                )
            }
            .sheet(
                isPresented: Binding(
                    get: { viewModel.gpxExportURL != nil },
                    set: { isPresented in if !isPresented { viewModel.clearGPXExport() } }
                )
            ) {
                if let url = viewModel.gpxExportURL {
                    ActivityView(activityItems: [url])
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var isInputEmpty: Bool {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func looksLikeURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("http") || trimmed.contains(".com") || trimmed.contains(".net")
    }
}
