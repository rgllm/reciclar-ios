import Foundation

public struct TilePage: Sendable {
    public var tile: SlippyTileCoordinate
    public var bounds: GeographicBounds
    public var page: LocationSyncPage

    public init(tile: SlippyTileCoordinate, bounds: GeographicBounds, page: LocationSyncPage) {
        self.tile = tile
        self.bounds = bounds
        self.page = page
    }
}

public struct CommunityEventsPage: Sendable {
    public var asOf: Date?
    public var events: [CommunityEvent]

    public init(asOf: Date?, events: [CommunityEvent]) {
        self.asOf = asOf
        self.events = events
    }
}

public struct LocationIDBatch: Sendable {
    public var locations: [Ecoponto]
    public var missing: [String]

    public init(locations: [Ecoponto], missing: [String]) {
        self.locations = locations
        self.missing = missing
    }
}

public protocol ReciclarAPIClient: Sendable {
    func fetchStats() async throws -> CatalogStatistics
    func fetchArea(bounds: GeographicBounds, cursor: String?) async throws -> AreaPage
    func fetchTile(_ tile: SlippyTileCoordinate, cursor: String?) async throws -> TilePage
    func fetchCommunityEvents(bounds: GeographicBounds) async throws -> CommunityEventsPage
    func fetchLocations(ids: [String]) async throws -> LocationIDBatch
    func fetchLocation(id: String) async throws -> LocationDetailResponse
    func submitReport(_ request: IssueSubmissionRequest) async throws -> CommunityEvent
    func submitResolution(_ request: IssueResolutionRequest) async throws -> CommunityEvent
}

public actor MockReciclarClient: ReciclarAPIClient {
    public var failNextFetch = false
    public var failNextSubmit = false
    public var submitCalls = 0
    private var submitDelay: (@Sendable () async -> Void)?
    public var pages: [LocationSyncPage]?
    public var tilePages: [String: [LocationSyncPage]] = [:]
    public var goneIDs: Set<String> = []
    public var extraLocations: [String: Ecoponto] = [:]
    public var snapshotCalls = 0
    public var tileCalls = 0
    public var eventCalls = 0
    public var idBatchCalls: [[String]] = []
    public var scriptedEvents: [CommunityEvent] = []
    public var nextError: ReciclarAPIError?
    private var extraEvents: [CommunityEvent] = []
    private let clock: @Sendable () -> Date

    public init(clock: @escaping @Sendable () -> Date = { Date() }) {
        self.clock = clock
    }

    public func fetchStats() async throws -> CatalogStatistics {
        try checkFetch()
        return DevelopmentFixtures.statistics(at: clock())
    }

    public func fetchArea(bounds: GeographicBounds, cursor: String?) async throws -> AreaPage {
        snapshotCalls += 1
        try checkFetch()
        var result: LocationSyncPage
        if let pages {
            result = page(from: pages, cursor: cursor, fallbackToken: "mock-token")
        } else {
            result = fixturePage(isCompleteReplacement: false)
        }
        result.locations = result.locations.filter { bounds.contains($0.coordinate) }
        result.isCompleteReplacement = false
        return AreaPage(bounds: bounds, page: result)
    }

    public func fetchTile(_ tile: SlippyTileCoordinate, cursor: String?) async throws -> TilePage {
        tileCalls += 1
        try consumeScriptedFailure()
        let source: [LocationSyncPage]
        if let scripted = tilePages[tile.cacheKey] {
            source = scripted
        } else if let pages {
            source = pages
        } else {
            source = [fixturePage(isCompleteReplacement: false)]
        }
        var page = page(from: source, cursor: cursor, fallbackToken: "tile")
        page.locations = page.locations.filter { tile.bounds.contains($0.coordinate) }
        page.communityEvents = []
        page.isCompleteReplacement = false
        if page.syncToken?.isEmpty != false {
            page.syncToken = "tile"
        }
        return TilePage(tile: tile, bounds: tile.bounds, page: page)
    }

    public func fetchCommunityEvents(bounds: GeographicBounds) async throws -> CommunityEventsPage {
        eventCalls += 1
        try consumeScriptedFailure()
        _ = bounds
        return CommunityEventsPage(asOf: clock(), events: scriptedEvents + extraEvents)
    }

    public func fetchLocations(ids: [String]) async throws -> LocationIDBatch {
        idBatchCalls.append(ids)
        try consumeScriptedFailure()
        guard ids.count <= MapTilePolicy.favouriteBatchLimit else { throw ReciclarAPIError.invalidResponse }
        let fixtures = DevelopmentFixtures.snapshot(at: clock(), extraEvents: extraEvents)
        var locations: [Ecoponto] = []
        var missing: [String] = []
        for id in ids {
            if goneIDs.contains(id) {
                missing.append(id)
                continue
            }
            if let extra = extraLocations[id] {
                locations.append(extra)
                continue
            }
            if let location = fixtures.location(id: id) {
                locations.append(location)
            } else {
                missing.append(id)
            }
        }
        return LocationIDBatch(locations: locations, missing: missing)
    }

    public func fetchLocation(id: String) async throws -> LocationDetailResponse {
        try checkFetch()
        if goneIDs.contains(id) {
            throw ReciclarAPIError.gone
        }
        if let extra = extraLocations[id] {
            return LocationDetailResponse(location: extra, communityEvents: extraEvents.filter { $0.ecopontoID == id })
        }
        let snapshot = DevelopmentFixtures.snapshot(at: clock(), extraEvents: extraEvents)
        guard let location = snapshot.location(id: id) else {
            throw ReciclarAPIError.notFound
        }
        return LocationDetailResponse(
            location: location,
            communityEvents: snapshot.communityEvents.filter { $0.ecopontoID == id }
        )
    }

    public func setSubmitDelay(_ delay: (@Sendable () async -> Void)?) {
        submitDelay = delay
    }

    public func submitReport(_ request: IssueSubmissionRequest) async throws -> CommunityEvent {
        submitCalls += 1
        if let submitDelay {
            await submitDelay()
        }
        return try submit(kind: .report, requestID: request.ecopontoID, issue: request.issue)
    }

    public func submitResolution(_ request: IssueResolutionRequest) async throws -> CommunityEvent {
        try submit(kind: .resolution, requestID: request.ecopontoID, issue: request.issue)
    }

    private func checkFetch() throws {
        if failNextFetch {
            failNextFetch = false
            throw ReciclarAPIError.unavailable
        }
    }

    private func consumeScriptedFailure() throws {
        try checkFetch()
        if let nextError {
            self.nextError = nil
            throw nextError
        }
    }

    private func fixturePage(isCompleteReplacement: Bool) -> LocationSyncPage {
        let snapshot = DevelopmentFixtures.snapshot(at: clock(), extraEvents: extraEvents)
        return LocationSyncPage(
            locations: snapshot.locations,
            communityEvents: snapshot.communityEvents,
            isCompleteReplacement: isCompleteReplacement,
            isFixtureData: true,
            hasMore: false,
            syncToken: "mock-token",
            coverageNote: DevelopmentFixtures.bannerText
        )
    }

    private func page(from pages: [LocationSyncPage], cursor: String?, fallbackToken: String) -> LocationSyncPage {
        if pages.isEmpty {
            return LocationSyncPage(
                locations: [],
                communityEvents: [],
                isCompleteReplacement: true,
                isFixtureData: true,
                hasMore: false,
                syncToken: fallbackToken
            )
        }
        if let cursor, let index = Int(cursor), pages.indices.contains(index) {
            return pages[index]
        }
        return pages[0]
    }

    private func submit(
        kind: CommunityEventKind,
        requestID: String,
        issue: CommunityIssueKind
    ) throws -> CommunityEvent {
        if failNextSubmit {
            failNextSubmit = false
            throw ReciclarAPIError.unavailable
        }
        let event = CommunityEvent(
            id: "mock-\(UUID().uuidString)",
            ecopontoID: requestID,
            issue: issue,
            kind: kind,
            serverTimestamp: clock()
        )
        extraEvents.append(event)
        return event
    }
}

public extension ReciclarAPIClient {
    func fetchArea(bounds: GeographicBounds, cursor: String?) async throws -> AreaPage {
        throw ReciclarAPIError.unavailable
    }

    func fetchTile(_ tile: SlippyTileCoordinate, cursor: String?) async throws -> TilePage {
        _ = (tile, cursor)
        throw ReciclarAPIError.unavailable
    }

    func fetchCommunityEvents(bounds: GeographicBounds) async throws -> CommunityEventsPage {
        _ = bounds
        throw ReciclarAPIError.unavailable
    }

    func fetchLocations(ids: [String]) async throws -> LocationIDBatch {
        _ = ids
        throw ReciclarAPIError.unavailable
    }
}
