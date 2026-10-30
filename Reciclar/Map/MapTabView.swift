import ReciclarCore
import SwiftUI

struct MapTabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSearch = false
    @State private var detailDetent: PresentationDetent = .large
    @State private var isShowingFilters = false
    @State private var presentListAfterFilters = false
    @State private var presentFavouritesAfterFilters = false

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .topTrailing) {
            EcopontoMapView(
                index: model.mapIndex(),
                revision: model.locationRevision,
                filter: model.filter,
                selectedID: $model.selectedLocationID,
                region: $model.mapRegion,
                showsUserLocation: model.locationService.showsUserLocation,
                reduceMotion: reduceMotion,
                now: model.now,
                onUserInteraction: { model.userStartedBrowsing() },
                attributionBottomInset: 168
            )
            .ignoresSafeArea()
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    MapCircleButton(
                        systemImage: "magnifyingglass",
                        accessibilityLabel: "Pesquisar lugar ou morada",
                        accessibilityHint: "Procura um sítio no mapa sem precisar da tua posição."
                    ) {
                        isShowingSearch = true
                    }
                    MapCircleButton(
                        systemImage: model.locationService.showsUserLocation ? "location.fill" : "location",
                        accessibilityLabel: "A minha posição",
                        accessibilityHint: "Pede a localização só para te mostrar no mapa."
                    ) {
                        Task { await model.centreOnUser() }
                    }
                }
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
            .safeAreaPadding(.top)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .overlay(alignment: .topLeading) {
            MapCircleButton(systemImage: "star", accessibilityLabel: "Favoritos") {
                model.isShowingFavourites = true
            }
            .padding(.top, 8)
            .padding(.leading, 16)
            .safeAreaPadding(.top)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .safeAreaInset(edge: .bottom, spacing: 8) {
            VStack(spacing: 8) {
                if model.snapshot.isFixtureData {
                    MapToast(text: DevelopmentFixtures.bannerText)
                        .padding(.horizontal, 24)
                        .accessibilityLabel("Aviso: \(DevelopmentFixtures.bannerText)")
                }
                if (model.status == .refreshing || model.status == .loading), model.mapEmptyReason == nil {
                    MapToast(text: "A atualizar…")
                }
                if let reason = model.mapEmptyReason {
                    MapStatusBanner(reason: reason)
                } else if let error = model.lastRefreshError, !model.snapshot.locations.isEmpty {
                    MapToast(text: error)
                        .padding(.horizontal, 24)
                }
                if model.isLocating {
                    MapToast(text: "A obter a tua posição…")
                        .padding(.horizontal, 24)
                } else if let feedback = model.locationFeedback {
                    MapToast(text: feedback)
                        .padding(.horizontal, 24)
                }
                if model.mapEmptyReason == nil, !hidesNoReadingLegend {
                    NoReadingLegend()
                        .padding(.horizontal, 16)
                }
                CategoryFilterBar {
                    isShowingFilters = true
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .sheet(isPresented: Binding(
            get: { model.selectedLocation != nil },
            set: { if !$0 { model.selectedLocationID = nil } }
        )) {
            if let location = model.selectedLocation {
                LocationDetailSheet(location: location)
                    .presentationDetents([.medium, .large], selection: $detailDetent)
                    .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: model.selectedLocationID) { _, id in
            if id != nil { detailDetent = .large }
        }
        .sheet(isPresented: $model.isShowingFavourites) {
            FavouritesView()
        }
        .sheet(isPresented: $model.isShowingList) {
            LocationListView()
        }
        .sheet(isPresented: $isShowingSearch) {
            MapSearchSheet()
        }
        .sheet(isPresented: $isShowingFilters, onDismiss: presentQueuedSheet) {
            MapFilterSheet(
                onShowList: { presentListAfterFilters = true },
                onShowFavourites: { presentFavouritesAfterFilters = true }
            )
        }
    }

    /// Store captures must not put the words "Sem leitura" back on the map.
    private var hidesNoReadingLegend: Bool {
        ProcessInfo.processInfo.arguments.contains("-StoreScreenshots")
    }

    private func presentQueuedSheet() {
        if presentListAfterFilters {
            presentListAfterFilters = false
            model.isShowingList = true
        } else if presentFavouritesAfterFilters {
            presentFavouritesAfterFilters = false
            model.isShowingFavourites = true
        }
    }
}

struct MapStatusBanner: View {
    let reason: MapEmptyReason
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: isEmptyCoverage ? .center : .leading, spacing: 10) {
            if isEmptyCoverage {
                Image(systemName: MapLoadCopy.symbol(reason))
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if !isEmptyCoverage {
                    Image(systemName: MapLoadCopy.symbol(reason))
                        .font(.body.weight(.semibold))
                        .accessibilityHidden(true)
                }
                VStack(alignment: isEmptyCoverage ? .center : .leading, spacing: 4) {
                    Text(MapLoadCopy.title(reason))
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(isEmptyCoverage ? .center : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(MapLoadCopy.detail(reason, error: model.lastRefreshError))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(isEmptyCoverage ? .center : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: isEmptyCoverage ? .center : .leading)
            }
            if MapLoadCopy.offersRetry(reason) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Text("Tentar novamente")
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.glassProminent)
            } else if reason == .noMatches {
                Button {
                    model.resetFilters()
                } label: {
                    Text("Limpar filtros")
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: isEmptyCoverage ? .center : .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
    }

    private var isEmptyCoverage: Bool { reason == .noLocations }
}
