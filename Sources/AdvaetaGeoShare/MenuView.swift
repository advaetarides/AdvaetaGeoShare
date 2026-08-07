import SwiftUI
import UniformTypeIdentifiers

struct MenuView: View {
    let routeStore: RouteStoring
    let launcher: MapAppOpening

    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var importAlertMessage: String?

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

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Text("Export Places & Routes")
                            .font(.heading(16))
                            .foregroundStyle(Color.bronze)
                            .padding(.vertical, 6)
                    }
                    .listRowBackground(Color.backgroundSoft)
                }

                Button {
                    showImporter = true
                } label: {
                    Text("Import Places & Routes")
                        .font(.heading(16))
                        .foregroundStyle(Color.bronze)
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
        .onAppear {
            exportURL = Self.writeExportFile(routes: routeStore.loadAll())
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .alert("Import", isPresented: Binding(
            get: { importAlertMessage != nil },
            set: { isPresented in if !isPresented { importAlertMessage = nil } }
        )) {
            Button("OK") { importAlertMessage = nil }
        } message: {
            Text(importAlertMessage ?? "")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let pickedURL) = result else {
            importAlertMessage = "Couldn't read that file."
            return
        }

        let didStartAccess = pickedURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                pickedURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: pickedURL),
              let imported = try? JSONDecoder().decode([SavedRoute].self, from: data) else {
            importAlertMessage = "That file doesn't look like an AdvaetaGeoShare backup."
            return
        }

        routeStore.importRoutes(imported)
        exportURL = Self.writeExportFile(routes: routeStore.loadAll())
        importAlertMessage = "Imported \(imported.count) saved place(s)/route(s)."
    }

    private static func writeExportFile(routes: [SavedRoute]) -> URL? {
        guard let data = try? JSONEncoder().encode(routes) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AdvaetaGeoShare-Backup.json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
