import SwiftUI

struct ContentView: View {
    @State private var viewModel: ConversionViewModel

    init(viewModel: ConversionViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("AdvaetaGeoShare")
                .font(.title2)
                .bold()

            TextField("Paste a Google Maps link", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Button("Open in OsmAnd") {
                Task {
                    await viewModel.convert()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.state == .resolving
            )

            switch viewModel.state {
            case .idle:
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
    }
}
