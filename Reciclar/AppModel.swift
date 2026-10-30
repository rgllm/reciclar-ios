import CoreLocation
import ReciclarCore
import Foundation
import MapKit
import SwiftUI

enum AppTab: Hashable {
    case map
    case sorting
    case stats
}

@MainActor
@Observable
final class AppModel {
    var selectedTab: AppTab = .map
    var snapshot = LocationSnapshot()
    var filter = LocationFilter()
    var selectedLocationID: Ecoponto.ID?
    var favouriteIDs: [String] = []
    var status: RepositoryStatus = .idle
    var lastRefreshError: String?
    var isShowingFavourites = false
    var isShowingList = false
    var mapRegion = MKCoordinateRegion.mainlandPortugal {
        didSet { if cacheReady { viewportChanged() } }
    }
    var areaComplete = false
    /// Observation token for `now`. Views re-render when this changes, at most once a minute.
    private var freshnessTick = Date()
    /// `distantFuture` until tracking starts, then the earliest time the clock may advance again.
    private var freshnessNotBefore = Date.distantFuture
    private var sceneIsActive = false
    private var freshnessTask: Task<Void, Never>?
    private var cacheReady = false
    private var viewportTask: Task<Void, Never>?
    private var viewportPersistTask: Task<Void, Never>?
    private var viewportPersistGeneration = 0
    private var persistedViewport: [Double]?
    private var viewportGeneration = 0
    private var browsingGeneration = 0
    private var appliedRevision = -1
    private var isRefreshingFavourites = false
    private let preparation = MapPreparationWorker()
    private let preferences = UserDefaults.standard
    var hasFittedMap = false
    var locationFeedback: String?
    var isLocating = false
    var issueFeedback: String?
    var isSubmittingIssue = false
    var reportDraft = IssueReportDraft()
    var reportChooserLocationID: String?
    var isCheckingReportPosition = false
    var filterChips: [WasteFilterChip] = []
    var locationRevision = 0
    var statistics: CatalogStatistics?
    var statsStatus: RepositoryStatus = .idle
    var statsError: String?

    let dependencies: AppDependencies
    let locationService: UserLocationService

    private var locationsByID: [String: Ecoponto] = [:]
    private var spatialIndex = SpatialIndex()

    init(dependencies: AppDependencies, locationService: UserLocationService) {
        self.dependencies = dependencies
        self.locationService = locationService
        if let values = preferences.array(forKey: "map.viewport") as? [Double], values.count == 4 {
            let bounds = GeographicBounds(center: Coordinate(latitude: values[0], longitude: values[1]),
                                          latitudeDelta: values[2], longitudeDelta: values[3], paddingFraction: 0)
            if bounds.isValid {
                mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: values[0], longitude: values[1]),
                                               span: MKCoordinateSpan(latitudeDelta: values[2], longitudeDelta: values[3]))
                persistedViewport = values
            }
        }
    }

    var now: Date { _ = freshnessTick; return dependencies.clock() }

    var sortingCatalog: SortingCatalog { dependencies.sortingCatalog }

    var visibleListLocations: [Ecoponto] {
        let bounds = visibleBounds
        return MapPresentationPolicy.listLocations(
            from: spatialIndex.locations(in: bounds),
            in: bounds,
            filter: filter,
            now: now
        )
    }

    var selectedLocation: Ecoponto? {
        guard let selectedLocationID else { return nil }
        return locationsByID[selectedLocationID]
    }

    var needsZoom: Bool { !viewportBounds.isValid || viewportBounds.maximumDimensionKilometres > 20 }

    var mapEmptyReason: MapEmptyReason? {
        switch MapLoadPresentationPolicy.presentation(
            needsZoom: needsZoom,
            visibleLocationCount: visibleListLocations.count,
            isLoading: status == .loading || status == .refreshing,
            refreshFailed: lastRefreshError != nil,
            areaLoaded: areaComplete,
            filtersActive: filter.isActive
        ) {
        case .zoomIn: return .zoomIn
        case .loading: return .loading
        case .failed: return .failedRefresh
        case .notCached: return .noCachedData
        case .noCoverage: return .noLocations
        case .noMatches: return .noMatches
        case .locations: return nil
        }
    }

    func start() async {
        guard !cacheReady else { return }
        // The map is already installed. Yield so that frame can commit before
        // favourites and the location cache are decoded.
        await Task.yield()
        await dependencies.favourites.load()
        favouriteIDs = await dependencies.favourites.identifiers()
        await dependencies.repository.protectFavourites(Set(favouriteIDs))
        await dependencies.repository.loadCache()
        await adoptIdentityRenames()
        await applySnapshot(fitIfNeeded: true)
        restartFreshnessTracking()
        await dependencies.stats.loadCache()
        await applyStatistics()
        cacheReady = true
        if snapshot.isFixtureData, let first = snapshot.locations.first { chooseArea(first.coordinate) }
        viewportChanged()
        if !snapshot.isFixtureData { await centreOnUser() }
        await viewportTask?.value
        await refreshMissingFavourites()
        await refreshStatistics(force: false)
    }

    func refresh() async {
        viewportChanged(force: true)
        await viewportTask?.value
        await refreshMissingFavourites(force: true)
        await refreshStatistics(force: true)
    }

    func refreshIfNeeded() async {
        guard cacheReady else { return }
        advanceFreshnessClockIfDue()
        viewportChanged()
        await viewportTask?.value
        await refreshMissingFavourites()
        await refreshStatistics(force: false)
    }

    func returnedToForeground() async {
        guard cacheReady else { return }
        await refreshIfNeeded()
        await recentreIfPermitted()
    }

    private func recentreIfPermitted() async {
        guard locationService.showsUserLocation else { return }
        await centreOnUser()
    }

    func userStartedBrowsing() {
        browsingGeneration += 1
        locationFeedback = nil
    }

    func chooseArea(_ coordinate: Coordinate, widthKilometres: Double = 3) {
        let latitude = widthKilometres / 111.32
        let longitude = latitude / max(cos(coordinate.latitude * .pi / 180), 0.1)
        mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
            span: MKCoordinateSpan(latitudeDelta: latitude, longitudeDelta: longitude))
    }

    func setSceneActive(_ active: Bool) {
        sceneIsActive = active
        if active {
            restartFreshnessTracking()
        } else {
            freshnessTask?.cancel()
            freshnessTask = nil
        }
    }

    /// While the scene is active, wake at the next fill or report change, and at least every minute.
    private func trackFreshness() async {
        if freshnessNotBefore == .distantFuture {
            freshnessNotBefore = .distantPast
        } else if freshnessNotBefore > .distantPast {
            // A resume after a scheduled wake should catch up. A restart that
            // only replaces an empty pre-cache sleep should not tick twice.
            advanceFreshnessClockIfDue()
        }
        while !Task.isCancelled {
            let now = dependencies.clock()
            let boundary = await freshnessBoundary(now: now)
            guard !Task.isCancelled else { return }
            let delay = FreshnessSchedule.delay(now: now, notBefore: freshnessNotBefore, nextBoundary: boundary)
            let wait = delay > 0 ? delay : 60
            do { try await Task.sleep(for: .seconds(wait)) } catch { return }
            guard !Task.isCancelled else { return }
            advanceFreshnessClockIfDue()
        }
    }

    /// Write the viewport immediately. Scene transitions call this so a debounced pan is not lost.
    func flushViewport() {
        viewportPersistGeneration += 1
        viewportPersistTask?.cancel()
        viewportPersistTask = nil
        writeViewport(currentViewportValues())
    }

    private func restartFreshnessTracking() {
        guard sceneIsActive else { return }
        freshnessTask?.cancel()
        freshnessTask = Task { [weak self] in
            await self?.trackFreshness()
        }
    }

    private func freshnessBoundary(now: Date) async -> Date? {
        let locations = snapshot.locations
        let events = snapshot.communityEvents
        if locations.isEmpty && events.isEmpty { return nil }
        // Keep this walk off the main actor and off the map-index worker.
        return await Task.detached(priority: .utility) {
            FreshnessSchedule.nextBoundary(locations: locations, events: events, now: now)
        }.value
    }

    private func advanceFreshnessClockIfDue() {
        let tick = dependencies.clock()
        guard tick >= freshnessNotBefore else { return }
        freshnessTick = tick
        freshnessNotBefore = tick.addingTimeInterval(60)
    }

    private func viewportChanged(force: Bool = false) {
        viewportTask?.cancel()
        viewportGeneration += 1
        let generation = viewportGeneration
        scheduleViewportPersist()
        areaComplete = false
        status = .idle
        lastRefreshError = nil
        guard !needsZoom else { return }
        let requestedBounds = visibleBounds
        let requiredBounds = viewportBounds
        viewportTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(force ? 0 : 200))
                try Task.checkCancellation()
                areaComplete = await dependencies.repository.isCovered(requiredBounds)
                if !force, !(await dependencies.repository.needsRefresh(requiredBounds, now: now)) {
                    await adoptIdentityRenames()
                    await applySnapshot(fitIfNeeded: false)
                    return
                }
                status = snapshot.locations.isEmpty ? .loading : .refreshing
                try await dependencies.repository.refreshArea(requestedBounds, now: now, force: force)
                await adoptIdentityRenames()
                try Task.checkCancellation()
                guard generation == viewportGeneration else { return }
                await applySnapshot(fitIfNeeded: false)
                areaComplete = await dependencies.repository.isCovered(requiredBounds)
                status = .idle
            } catch is CancellationError {
                await adoptIdentityRenames()
            }
            catch {
                await adoptIdentityRenames()
                guard generation == viewportGeneration else { return }
                let apiMessage = (error as? ReciclarAPIError)?.userMessage
                lastRefreshError = apiMessage ?? "Não foi possível atualizar esta zona. A informação guardada continua disponível."
                status = .failed(lastRefreshError!)
            }
        }
    }

    func refreshStatistics(force: Bool = true) async {
        await dependencies.stats.refreshIfNeeded(now: now, force: force)
        await applyStatistics()
    }

    func toggleToken(_ token: LocationFilterToken) {
        filter.toggle(token)
        if let selected = selectedLocation, !filter.matches(selected, at: now) {
            selectedLocationID = nil
        }
        locationRevision += 1
    }

    func toggleSpaceAvailable() {
        filter.requiresSpaceAvailable.toggle()
        locationRevision += 1
    }

    func resetFilters() {
        filter.reset()
        locationRevision += 1
    }

    func toggleFavourite(_ id: String) async {
        await dependencies.favourites.toggle(id, at: now)
        favouriteIDs = await dependencies.favourites.identifiers()
        await dependencies.repository.protectFavourites(Set(favouriteIDs))
    }

    func isFavourite(_ id: String) -> Bool {
        favouriteIDs.contains(id)
    }

    func favouriteAvailability(_ id: String) -> FavouriteAvailability {
        if locationsByID[id] != nil { return .available }
        if snapshot.removedLocationIDs.contains(id) { return .removedFromSource }
        if snapshot.hasCompletedSync { return .unavailable }
        return .pending
    }

    func openMap(categories: Set<WasteCategory.ID>) {
        var tokens = Set<LocationFilterToken>()
        for id in categories {
            if id == WasteCategory.sampleGlass.id {
                tokens.insert(.stream(.glass))
            } else if id == WasteCategory.samplePaper.id {
                tokens.insert(.stream(.paper))
            } else if id == WasteCategory.samplePackaging.id {
                tokens.insert(.stream(.packaging))
            } else if let chip = filterChips.first(where: { $0.categoryIDs.contains(id) }) {
                tokens.insert(chip.token)
            }
        }
        filter.requiredCategories = []
        filter.requiredTokens = tokens
        filter.requiresSpaceAvailable = false
        selectedTab = .map
        selectedLocationID = nil
        locationRevision += 1
    }

    func resolveIssue(for location: Ecoponto, kind: CommunityIssueKind) async {
        guard !isSubmittingIssue else { return }
        isSubmittingIssue = true
        issueFeedback = nil
        defer { isSubmittingIssue = false }

        guard await locationService.prepareForProximityCheck() else {
            issueFeedback = locationService.permissionExplanation
            return
        }
        guard case .withinRange = Geodesy.evaluate(
            destination: location.coordinate,
            fix: locationService.lastFix,
            now: now
        ) else {
            issueFeedback = "Tens de estar junto do ecoponto, com uma posição recente, para dar o problema como resolvido."
            return
        }
        do {
            _ = try await dependencies.repository.submitResolution(
                IssueResolutionRequest(ecopontoID: location.id, issue: kind)
            )
            await applySnapshot(fitIfNeeded: false)
            issueFeedback = "O problema deixou de estar visível para os outros."
        } catch let error as ReciclarAPIError {
            issueFeedback = error.userMessage
                ?? "Não foi possível confirmar a resolução. Tenta outra vez."
        } catch {
            issueFeedback = "Não foi possível confirmar a resolução. Tenta outra vez."
        }
    }

    func reportAvailability(for location: Ecoponto) -> IssueReportAvailability {
        IssueReportPolicy.availability(
            destination: location.coordinate,
            fix: locationService.lastFix,
            access: locationService.reportAccess,
            isSubmitting: reportDraft.isSubmitting || isSubmittingIssue,
            isCheckingPosition: isCheckingReportPosition,
            now: now
        )
    }

    func refreshReportPositionIfAuthorized() {
        guard locationService.showsUserLocation else { return }
        Task { await refreshReportPosition() }
    }

    func refreshReportPosition() async {
        guard !isCheckingReportPosition else { return }
        isCheckingReportPosition = true
        defer { isCheckingReportPosition = false }
        _ = await locationService.prepareForProximityCheck()
    }

    func openReportChooser(for location: Ecoponto) {
        guard reportAvailability(for: location).isEnabled else { return }
        reportChooserLocationID = location.id
    }

    func selectReportIssue(_ issue: CommunityIssueKind, for location: Ecoponto) {
        reportDraft.select(issue, for: location.id)
    }

    func submitReport(for location: Ecoponto) async {
        guard !isSubmittingIssue else { return }
        let proximity = IssueReportPolicy.availability(
            destination: location.coordinate,
            fix: locationService.lastFix,
            access: locationService.reportAccess,
            isSubmitting: false,
            isCheckingPosition: false,
            now: now
        )
        guard proximity.isEnabled else { return }
        guard let issue = reportDraft.beginSending(for: location.id) else { return }
        guard case .withinRange = Geodesy.evaluate(
            destination: location.coordinate,
            fix: locationService.lastFix,
            now: now
        ) else {
            reportDraft.finishFailure(proximity.explanation ?? IssueReportPolicy.failureFallback)
            return
        }
        do {
            _ = try await dependencies.repository.submitReport(
                IssueSubmissionRequest(ecopontoID: location.id, issue: issue)
            )
            await applySnapshot(fitIfNeeded: false)
            reportDraft.finishSuccess()
            reportChooserLocationID = nil
            issueFeedback = IssueReportPolicy.successMessage
        } catch let error as ReciclarAPIError {
            reportDraft.finishFailure(error.userMessage ?? IssueReportPolicy.failureFallback)
        } catch {
            reportDraft.finishFailure(IssueReportPolicy.failureFallback)
        }
    }

    func visibleIssues(for location: Ecoponto) -> [VisibleCommunityIssue] {
        CommunityIssuePolicy.visibleIssues(in: snapshot.communityEvents, for: location.id, at: now)
    }

    func centreOnUser() async {
        guard !isLocating else { return }
        isLocating = true
        locationFeedback = nil
        defer { isLocating = false }
        let browsing = browsingGeneration
        guard await locationService.prepareForDisplay() else {
            guard browsing == browsingGeneration else { return }
            locationFeedback = locationService.isDenied
                ? "Sem acesso à localização. Podes explorar o mapa ou pesquisar um lugar."
                : "Sem posição disponível. Podes explorar o mapa ou tentar novamente no botão de localização."
            return
        }
        guard browsing == browsingGeneration else { return }
        if let fix = locationService.displayFix {
            chooseArea(fix.coordinate, widthKilometres: MapLocationPolicy.widthKilometres(for: fix))
            if now.timeIntervalSince(fix.timestamp) >= 30 {
                locationFeedback = "Última posição conhecida · \(PortugueseRelativeTime.phrase(from: fix.timestamp, now: now))"
            } else if fix.horizontalAccuracy > 1_000 {
                locationFeedback = "A mostrar a tua localização aproximada."
            }
        }
    }

    func mapIndex() -> SpatialIndex { spatialIndex }

    private func applySnapshot(fitIfNeeded: Bool) async {
        let (next, revision) = await dependencies.repository.currentState()
        guard revision != appliedRevision else { return }
        if next.locations != snapshot.locations || next.cachedAreas.map(\.locationIDs) != snapshot.cachedAreas.map(\.locationIDs) {
            // Retained favourite details may be absent from the latest area membership.
            let mappedIDs = next.cachedAreas.reduce(Set<String>()) { $0.union($1.locationIDs) }
            let mapLocations = next.cachedAreas.isEmpty ? next.locations : next.locations.filter { mappedIDs.contains($0.id) }
            let (index, chips) = await preparation.prepare(mapLocations)
            guard revision >= appliedRevision else { return }
            spatialIndex = index
            filterChips = chips
            locationsByID = Dictionary(next.locations.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
            locationRevision += 1
        }
        snapshot = next
        appliedRevision = revision
    }

    private func applyStatistics() async {
        statistics = await dependencies.stats.current()
        statsStatus = await dependencies.stats.status
        statsError = await dependencies.stats.lastRefreshError
    }

    private func refreshMissingFavourites(force: Bool = false) async {
        guard !isRefreshingFavourites else { return }
        isRefreshingFavourites = true
        defer { isRefreshingFavourites = false }
        await dependencies.repository.refreshFavourites(favouriteIDs, now: now, force: force)
        await adoptIdentityRenames()
        await applySnapshot(fitIfNeeded: false)
    }

    /// Rewrites saved retired location ids to the public id recorded with the cache.
    private func adoptIdentityRenames() async {
        let renames = await dependencies.repository.currentSnapshot().identityRenames
        guard !renames.isEmpty else { return }
        for (legacy, published) in renames {
            await dependencies.favourites.replace(legacy, with: published)
            if selectedLocationID == legacy { selectedLocationID = published }
            if reportChooserLocationID == legacy { reportChooserLocationID = published }
            if reportDraft.ecopontoID == legacy { reportDraft.ecopontoID = published }
        }
        favouriteIDs = await dependencies.favourites.identifiers()
        await dependencies.repository.protectFavourites(Set(favouriteIDs))
        try? await dependencies.repository.clearIdentityRenames(Set(renames.keys))
    }

    private func scheduleViewportPersist() {
        viewportPersistGeneration += 1
        let generation = viewportPersistGeneration
        viewportPersistTask?.cancel()
        viewportPersistTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled, generation == self.viewportPersistGeneration else { return }
            self.writeViewport(self.currentViewportValues())
        }
    }

    private func currentViewportValues() -> [Double] {
        [
            mapRegion.center.latitude,
            mapRegion.center.longitude,
            mapRegion.span.latitudeDelta,
            mapRegion.span.longitudeDelta
        ]
    }

    private func writeViewport(_ values: [Double]) {
        guard values != persistedViewport else { return }
        persistedViewport = values
        preferences.set(values, forKey: "map.viewport")
    }

    private var viewportBounds: GeographicBounds {
        GeographicBounds(center: Coordinate(latitude: mapRegion.center.latitude, longitude: mapRegion.center.longitude),
                         latitudeDelta: mapRegion.span.latitudeDelta, longitudeDelta: mapRegion.span.longitudeDelta,
                         paddingFraction: 0)
    }

    private var visibleBounds: GeographicBounds {
        GeographicBounds(
            center: Coordinate(latitude: mapRegion.center.latitude, longitude: mapRegion.center.longitude),
            latitudeDelta: mapRegion.span.latitudeDelta,
            longitudeDelta: mapRegion.span.longitudeDelta
        )
    }
}

enum FavouriteAvailability: Equatable, Sendable {
    case available
    case pending
    case unavailable
    case removedFromSource
}

extension MKCoordinateRegion {
    static let mainlandPortugal = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.6, longitude: -8.0),
        span: MKCoordinateSpan(latitudeDelta: 4.8, longitudeDelta: 4.8)
    )

    static func fitting(_ coordinates: [Coordinate]) -> MKCoordinateRegion {
        guard let first = coordinates.first else { return .mainlandPortugal }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.4, 0.03),
                longitudeDelta: max((maxLon - minLon) * 1.4, 0.03)
            )
        )
    }
}

enum MapEmptyReason {
    case zoomIn
    case noLocations
    case loading
    case noCachedData
    case failedRefresh
    case noMatches
}
