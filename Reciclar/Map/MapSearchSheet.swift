import ReciclarCore
import MapKit
import SwiftUI

struct MapSearchSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchFailed = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
                    Text("Escreve pelo menos 3 letras para procurar um lugar ou uma morada. Não precisas de autorizar a localização.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else if isSearching {
                    ProgressView("A pesquisar…")
                } else if searchFailed {
                    ContentUnavailableView("Não foi possível pesquisar", systemImage: "wifi.exclamationmark", description: Text("Verifica a ligação e tenta novamente."))
                } else if searchResults.isEmpty {
                    ContentUnavailableView(
                        "Sem resultados",
                        systemImage: "mappin.slash",
                        description: Text("Tenta outro lugar ou morada.")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                ForEach(Array(searchResults.enumerated()), id: \.offset) { _, item in
                    Button {
                        centre(on: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Resultado")
                                .foregroundStyle(.primary)
                            if let subtitle = subtitle(for: item) {
                                Text(subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pesquisar")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Lugar ou morada")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .onChange(of: searchText) { _, query in
                search(query)
            }
        }
        .onDisappear { searchTask?.cancel() }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func search(_ query: String) {
        searchTask?.cancel()
        searchFailed = false
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchResults = []
        searchTask = Task {
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmed
            request.region = model.mapRegion
            request.resultTypes = [.address, .pointOfInterest]
            do {
                let response = try await MKLocalSearch(request: request).start()
                guard !Task.isCancelled else { return }
                searchResults = Array(response.mapItems.prefix(8))
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
                isSearching = false
                searchFailed = true
            }
        }
    }

    private func centre(on item: MKMapItem) {
        model.userStartedBrowsing()
        model.chooseArea(Coordinate(latitude: item.location.coordinate.latitude, longitude: item.location.coordinate.longitude))
        dismiss()
    }

    private func subtitle(for item: MKMapItem) -> String? {
        item.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
    }
}
