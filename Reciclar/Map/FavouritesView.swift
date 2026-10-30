import ReciclarCore
import SwiftUI

struct FavouritesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if model.favouriteIDs.isEmpty {
                    ContentUnavailableView(
                        "Sem favoritos",
                        systemImage: "star",
                        description: Text("Podes guardar um ecoponto a partir dos detalhes. Isto não significa que tenha espaço.")
                    )
                } else {
                    ForEach(model.favouriteIDs, id: \.self) { id in
                        if let location = model.snapshot.location(id: id) {
                            Button {
                                model.selectedLocationID = id
                                model.mapRegion = .fitting([location.coordinate])
                                dismiss()
                                model.isShowingFavourites = false
                                model.selectedTab = .map
                            } label: {
                                LocationRow(
                                    location: location,
                                    issues: model.visibleIssues(for: location),
                                    space: LocationFilter().spaceStatus(of: location, at: model.now),
                                    now: model.now
                                )
                            }
                            .foregroundStyle(.primary)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ecoponto guardado")
                                    .font(.headline)
                                Text(favouriteDetail(model.favouriteAvailability(id)))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Favorito sem dados atuais")
                            .swipeActions {
                                Button("Remover", role: .destructive) {
                                    Task { await model.toggleFavourite(id) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favoritos")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    private func favouriteDetail(_ availability: FavouriteAvailability) -> String {
        switch availability {
        case .available:
            ""
        case .pending:
            "Ainda estou a carregar os dados deste favorito."
        case .unavailable:
            "Os dados deste favorito não vieram na última atualização. Não assumo que o local tenha sido removido."
        case .removedFromSource:
            "Este ecoponto já não consta da fonte. O favorito ficou guardado neste aparelho."
        }
    }
}

struct LocationListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var locations: [Ecoponto] { model.visibleListLocations }

    var body: some View {
        NavigationStack {
            Group {
                if locations.isEmpty {
                    emptyState
                } else {
                    List(locations) { location in
                        Button {
                            model.selectedLocationID = location.id
                            model.mapRegion = .fitting([location.coordinate])
                            dismiss()
                        } label: {
                            LocationRow(
                                location: location,
                                issues: model.visibleIssues(for: location),
                                space: model.filter.spaceStatus(of: location, at: model.now),
                                now: model.now
                            )
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Lista")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let reason = model.mapEmptyReason, MapLoadCopy.offersRetry(reason) {
            ContentUnavailableView {
                Label(MapLoadCopy.title(reason), systemImage: MapLoadCopy.symbol(reason))
            } description: {
                Text(MapLoadCopy.detail(reason, error: model.lastRefreshError))
            } actions: {
                Button("Tentar novamente") {
                    Task { await model.refresh() }
                }
            }
        } else if model.mapEmptyReason == .noMatches {
            ContentUnavailableView {
                Label(MapLoadCopy.title(.noMatches), systemImage: MapLoadCopy.symbol(.noMatches))
            } description: {
                Text(MapLoadCopy.detail(.noMatches, error: nil))
            } actions: {
                Button("Limpar filtros") { model.resetFilters() }
            }
        } else if let reason = model.mapEmptyReason {
            ContentUnavailableView(
                MapLoadCopy.title(reason),
                systemImage: MapLoadCopy.symbol(reason),
                description: Text(MapLoadCopy.detail(reason, error: model.lastRefreshError))
            )
        } else {
            ContentUnavailableView(
                "Sem ecopontos para mostrar",
                systemImage: "mappin.slash",
                description: Text("Não há ecopontos nesta vista.")
            )
        }
    }
}

struct LocationRow: View {
    let location: Ecoponto
    let issues: [VisibleCommunityIssue]
    let space: LocationSpaceStatus
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(location.displayName)
                .font(.headline)
            if let place = location.placeLine {
                Text(place)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(location.acceptedCategories) { category in
                    Label(category.name, systemImage: WasteCategoryPresentation.symbol(for: category))
                        .font(.caption)
                        .foregroundStyle(WasteCategoryPresentation.color(for: category))
                }
            }
            HStack(spacing: 4) {
                Image(systemName: MapPalette.symbolName(for: space.availability))
                    .foregroundStyle(MapPalette.color(for: space.availability))
                    .accessibilityHidden(true)
                Text(space.portugueseLabel)
                    .foregroundStyle(.primary)
            }
            .font(.caption.weight(.semibold))
            if !issues.isEmpty {
                ForEach(issues) { issue in
                    Text(PortugueseRelativeTime.reportedPhrase(kind: issue.kind, from: issue.reportedAt, now: now))
                        .font(.caption)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [location.displayName]
        if let place = location.placeLine {
            parts.append(place)
        }
        let categories = location.acceptedCategories.map(\.name).joined(separator: ", ")
        if !categories.isEmpty {
            parts.append(categories)
        }
        parts.append(space.accessibilityLabel)
        for issue in issues {
            parts.append(PortugueseRelativeTime.reportedPhrase(kind: issue.kind, from: issue.reportedAt, now: now))
        }
        return parts.joined(separator: ". ")
    }
}
