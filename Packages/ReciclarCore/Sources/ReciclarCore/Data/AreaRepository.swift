import Foundation
#if canImport(os)
import os
#endif

public struct CachedArea: Codable, Hashable, Sendable {
    public var bounds: GeographicBounds
    public var syncedAt: Date
    public var accessedAt: Date
    public var locationIDs: Set<String>
    /// Slippy-map identity. Nil for caches written before tile loading.
    public var tileZoom: Int?
    public var tileX: Int?
    public var tileY: Int?

    public init(bounds: GeographicBounds, syncedAt: Date, locationIDs: Set<String>, tile: SlippyTileCoordinate? = nil) {
        self.bounds = bounds
        self.syncedAt = syncedAt
        self.accessedAt = syncedAt
        self.locationIDs = locationIDs
        self.tileZoom = tile?.z
        self.tileX = tile?.x
        self.tileY = tile?.y
    }

    public var tile: SlippyTileCoordinate? {
        guard let tileZoom, let tileX, let tileY else { return nil }
        return SlippyTileCoordinate(z: tileZoom, x: tileX, y: tileY)
    }
}

public struct AreaPage: Sendable {
    public var bounds: GeographicBounds
    public var page: LocationSyncPage
    public init(bounds: GeographicBounds, page: LocationSyncPage) { self.bounds = bounds; self.page = page }
}

public actor AreaRepository {
    private let client: any ReciclarAPIClient
    private let store: any SnapshotStore
    private let tileZoom: Int
    private var snapshot = LocationSnapshot()
    private var working = LocationSnapshot()
    private var rollback = LocationSnapshot()
    private var protectedIDs: Set<String> = []
    private var applyTail: Task<Void, Never>?
    private var dirty = false
    private var saveQueued = false
    private var saveWaiters: [SaveWaiter] = []
    private var requestGeneration = 0
    private var retryAfter: Date?
    private var backoffStep = 0
    private var blockedError: ReciclarAPIError = .unavailable
    private var favouriteFetchedAt: [String: Date] = [:]
    /// Tile routes answer 404 until that route is available. Skip them until this instant, then try once.
    private var tilesUnavailableUntil: Date?
    private let byteLimit: Int
    public private(set) var revision = 0
    public private(set) var lastRefreshError: String?
    #if canImport(os)
    private let signposter = OSSignposter(subsystem: "pt.ecopontos.app", category: "AreaRepository")
    #endif
    private let reportGate = IssueReportGate()
    private static let diskCoalesceNanoseconds: UInt64 = 100_000_000

    public init(
        client: any ReciclarAPIClient,
        store: any SnapshotStore,
        byteLimit: Int = 50 * 1024 * 1024,
        tileZoom: Int = MapTilePolicy.zoom
    ) {
        self.client = client
        self.store = store
        self.byteLimit = byteLimit
        self.tileZoom = tileZoom
    }

    public func currentSnapshot() -> LocationSnapshot { snapshot }
    public func currentState() -> (snapshot: LocationSnapshot, revision: Int) { (snapshot, revision) }
    public func protectFavourites(_ ids: Set<String>) { protectedIDs = ids }

    /// Drops renames after favourites have stored the public ids. Unknown keys are ignored.
    public func clearIdentityRenames(_ applied: Set<String>) async throws {
        guard !applied.isEmpty else { return }
        try await commit { current in
            var next = current
            for id in applied {
                next.identityRenames.removeValue(forKey: id)
            }
            return next
        }
    }

    public func loadCache() async {
        #if canImport(os)
        let interval = signposter.beginInterval("CacheRead")
        defer { signposter.endInterval("CacheRead", interval) }
        #endif
        do {
            if let cached = try await store.load() {
                snapshot = cached
                working = cached
                rollback = cached
                revision += 1
            }
        } catch is CancellationError {
            return
        } catch { lastRefreshError = "Não foi possível ler os dados guardados. Tenta atualizar esta zona." }
    }

    public func needsRefresh(_ bounds: GeographicBounds, now: Date) -> Bool {
        let locationsFresh: Bool
        if tilesAreAvailable(at: now) {
            guard let tiles = try? SlippyMapTiles.covering(bounds, zoom: tileZoom) else { return true }
            locationsFresh = tiles.allSatisfy { isFresh($0, now: now) }
            if locationsFresh { touch(tiles, now: now) }
        } else {
            locationsFresh = isBBoxFresh(bounds, now: now)
            if locationsFresh { touchBBox(bounds, now: now) }
        }
        let eventsFresh = isEventAreaFresh(bounds, now: now)
        if eventsFresh { touchEvents(bounds, now: now) }
        return !(locationsFresh && eventsFresh)
    }

    public func isCovered(_ bounds: GeographicBounds) -> Bool {
        if snapshot.cachedAreas.contains(where: { $0.tile == nil && $0.bounds.contains(bounds) }) { return true }
        guard let tiles = try? SlippyMapTiles.covering(bounds, zoom: tileZoom) else { return false }
        return tiles.allSatisfy { tile in snapshot.cachedAreas.contains { $0.tile == tile } }
    }

    public func refreshArea(_ bounds: GeographicBounds, now: Date, force: Bool = false) async throws {
        guard bounds.isValid, bounds.maximumDimensionKilometres <= 24.1 else { throw ReciclarAPIError.invalidResponse }
        let tiles = try SlippyMapTiles.covering(bounds, zoom: tileZoom)
        let eventsStale = force || !isEventAreaFresh(bounds, now: now)
        let tryTiles = force || tilesAreAvailable(at: now)
        if tryTiles {
            let staleTiles = tiles.filter { force || !isFresh($0, now: now) }
            if staleTiles.isEmpty, !eventsStale {
                touch(tiles, now: now)
                touchEvents(bounds, now: now)
                return
            }
        } else if isBBoxFresh(bounds, now: now), !eventsStale {
            touchBBox(bounds, now: now)
            touchEvents(bounds, now: now)
            return
        }
        if !force, let retryAfter, now < retryAfter { throw blockedError }
        requestGeneration += 1
        let generation = requestGeneration
        #if canImport(os)
        let interval = signposter.beginInterval("AreaFetch")
        defer { signposter.endInterval("AreaFetch", interval) }
        #endif
        do {
            if tryTiles {
                let staleTiles = tiles.filter { force || !isFresh($0, now: now) }
                do {
                    for tile in staleTiles {
                        try await fetchTile(tile, generation: generation, now: now)
                    }
                    tilesUnavailableUntil = nil
                    if eventsStale {
                        do { try await fetchEvents(bounds, generation: generation, now: now) }
                        catch ReciclarAPIError.notFound { }
                    }
                } catch ReciclarAPIError.notFound {
                    tilesUnavailableUntil = now.addingTimeInterval(MapTilePolicy.freshness)
                    try await fetchBBox(bounds, generation: generation, now: now)
                }
            } else {
                try await fetchBBox(bounds, generation: generation, now: now)
            }
            lastRefreshError = nil
            retryAfter = nil
            backoffStep = 0
            blockedError = .unavailable
        } catch is CancellationError { throw CancellationError() }
        catch {
            if generation == requestGeneration { noteFailure(error, now: now) }
            throw error
        }
    }

    private func tilesAreAvailable(at now: Date) -> Bool {
        guard let tilesUnavailableUntil else { return true }
        return now >= tilesUnavailableUntil
    }

    private func fetchBBox(_ bounds: GeographicBounds, generation: Int, now: Date) async throws {
        var locations: [String: Ecoponto] = [:]
        var events: [String: CommunityEvent] = [:]
        var cursor: String?
        var seen = Set<String>()
        var token: String?
        var fixture = false
        var complete = false
        for _ in 0..<1_000 {
            try Task.checkCancellation()
            let result = try await client.fetchArea(bounds: bounds, cursor: cursor)
            let page = result.page
            guard generation == requestGeneration else { throw CancellationError() }
            guard result.bounds == bounds, !page.isCompleteReplacement,
                  let version = page.syncToken, !version.isEmpty,
                  token == nil || token == version,
                  page.locations.allSatisfy({ $0.coordinate.isValid && bounds.contains($0.coordinate) }) else {
                throw ReciclarAPIError.invalidResponse
            }
            token = version
            fixture = page.isFixtureData
            for location in page.locations { locations[location.id] = location }
            for event in page.communityEvents { events[event.id] = event }
            if !page.hasMore { complete = true; break }
            guard let next = page.nextCursor, !next.isEmpty, seen.insert(next).inserted else {
                throw ReciclarAPIError.invalidResponse
            }
            cursor = next
        }
        guard complete else { throw ReciclarAPIError.invalidResponse }
        let fetchedLocations = locations
        let fetchedEvents = events
        let isFixture = fixture
        let protected = protectedIDs
        let limit = byteLimit
        try await commit { current in
            var next = current
            var all = Dictionary(current.locations.map { ($0.id, $0) }, uniquingKeysWith: { _, b in b })
            for (id, location) in fetchedLocations { all[id] = location }
            let absent = Set(current.locations.filter { bounds.contains($0.coordinate) && fetchedLocations[$0.id] == nil }.map(\.id))
            for index in next.cachedAreas.indices { next.cachedAreas[index].locationIDs.subtract(absent) }
            for id in absent where !protected.contains(id) { all.removeValue(forKey: id) }
            next.cachedAreas.removeAll { bounds.contains($0.bounds) }
            next.cachedAreas.append(CachedArea(bounds: bounds, syncedAt: now, locationIDs: Set(fetchedLocations.keys)))
            var allEvents = Dictionary(current.communityEvents.map { ($0.id, $0) }, uniquingKeysWith: { _, b in b })
            for (id, event) in fetchedEvents { allEvents[id] = event }
            next.communityEvents = allEvents.values.filter {
                now.timeIntervalSince($0.serverTimestamp) <= CommunityIssuePolicy.expiry + 24 * 60 * 60
            }
            next.communityEventAreas.removeAll { bounds.contains($0.bounds) }
            next.communityEventAreas.append(CachedArea(bounds: bounds, syncedAt: now, locationIDs: []))
            LocationIdentityCrosswalk.apply(
                existing: current.locations,
                fetched: Array(fetchedLocations.values),
                to: &next,
                locations: &all
            )
            next.locations = Array(all.values)
            next.isFixtureData = isFixture
            next.syncToken = nil
            next.lastSuccessfulSync = nil
            var estimated = CacheByteLedger.measure(next)
            while estimated.total > limit {
                guard let oldest = next.cachedAreas.indices.filter({ !bounds.contains(next.cachedAreas[$0].bounds) })
                    .min(by: { next.cachedAreas[$0].accessedAt < next.cachedAreas[$1].accessedAt }) else { break }
                let removedArea = next.cachedAreas.remove(at: oldest)
                let retained = next.cachedAreas.reduce(protected) { $0.union($1.locationIDs) }.union(fetchedLocations.keys)
                let removedLocations = next.locations.filter { !retained.contains($0.id) }
                let removedEvents = next.communityEvents.filter { !retained.contains($0.ecopontoID) }
                next.locations.removeAll { !retained.contains($0.id) }
                next.communityEvents.removeAll { !retained.contains($0.ecopontoID) }
                estimated.removeArea(removedArea, remaining: next.cachedAreas.count)
                estimated.removeLocations(removedLocations, remaining: next.locations.count)
                estimated.removeEvents(removedEvents, remaining: next.communityEvents.count)
            }
            let retained = next.cachedAreas.reduce(protected) { $0.union($1.locationIDs) }
            next.locations.removeAll { !retained.contains($0.id) }
            return next
        }
    }

    private func fetchTile(_ tile: SlippyTileCoordinate, generation: Int, now: Date) async throws {
        var locations: [String: Ecoponto] = [:]
        var cursor: String?
        var seen = Set<String>()
        var token: String?
        var fixture = false
        var complete = false
        for _ in 0..<1_000 {
            try Task.checkCancellation()
            let result = try await client.fetchTile(tile, cursor: cursor)
            let page = result.page
            guard generation == requestGeneration else { throw CancellationError() }
            guard result.tile == tile,
                  let version = page.syncToken, !version.isEmpty,
                  token == nil || token == version,
                  page.locations.allSatisfy({ accepted($0, in: result.bounds, tile: tile) }) else {
                throw ReciclarAPIError.invalidResponse
            }
            token = version
            fixture = page.isFixtureData
            for location in page.locations { locations[location.id] = location }
            if !page.hasMore { complete = true; break }
            guard let next = page.nextCursor, !next.isEmpty, seen.insert(next).inserted else {
                throw ReciclarAPIError.invalidResponse
            }
            cursor = next
        }
        guard complete else { throw ReciclarAPIError.invalidResponse }
        let fetchedLocations = locations
        let isFixture = fixture
        let protected = protectedIDs
        let limit = byteLimit
        let zoom = tileZoom
        try await commit { current in
            var next = current
            var all = Dictionary(current.locations.map { ($0.id, $0) }, uniquingKeysWith: { _, b in b })
            for (id, location) in fetchedLocations { all[id] = location }
            let previousIDs = current.cachedAreas.first { $0.tile == tile }?.locationIDs ?? []
            let gone = previousIDs.subtracting(fetchedLocations.keys).filter { id in
                guard let location = all[id] else { return true }
                return SlippyMapTiles.tile(containing: location.coordinate, zoom: zoom) == tile
            }
            for index in next.cachedAreas.indices where next.cachedAreas[index].tile == nil {
                next.cachedAreas[index].locationIDs.subtract(gone)
            }
            for id in gone where !protected.contains(id) { all.removeValue(forKey: id) }
            next.cachedAreas.removeAll { $0.tile == tile }
            next.cachedAreas.append(CachedArea(bounds: tile.bounds, syncedAt: now, locationIDs: Set(fetchedLocations.keys), tile: tile))
            LocationIdentityCrosswalk.apply(
                existing: current.locations,
                fetched: Array(fetchedLocations.values),
                to: &next,
                locations: &all
            )
            next.locations = Array(all.values)
            next.isFixtureData = isFixture
            next.syncToken = nil
            next.lastSuccessfulSync = nil
            var estimated = CacheByteLedger.measure(next)
            while estimated.total > limit {
                guard let oldest = next.cachedAreas.indices.filter({ next.cachedAreas[$0].tile != tile })
                    .min(by: { next.cachedAreas[$0].accessedAt < next.cachedAreas[$1].accessedAt }) else { break }
                let removedArea = next.cachedAreas.remove(at: oldest)
                let retained = next.cachedAreas.reduce(protected) { $0.union($1.locationIDs) }.union(fetchedLocations.keys)
                let removedLocations = next.locations.filter { !retained.contains($0.id) }
                let removedEvents = next.communityEvents.filter { !retained.contains($0.ecopontoID) }
                next.locations.removeAll { !retained.contains($0.id) }
                next.communityEvents.removeAll { !retained.contains($0.ecopontoID) }
                estimated.removeArea(removedArea, remaining: next.cachedAreas.count)
                estimated.removeLocations(removedLocations, remaining: next.locations.count)
                estimated.removeEvents(removedEvents, remaining: next.communityEvents.count)
            }
            let retained = next.cachedAreas.reduce(protected) { $0.union($1.locationIDs) }
            next.locations.removeAll { !retained.contains($0.id) }
            return next
        }
    }

    private func fetchEvents(_ bounds: GeographicBounds, generation: Int, now: Date) async throws {
        try Task.checkCancellation()
        let page = try await client.fetchCommunityEvents(bounds: bounds)
        guard generation == requestGeneration else { throw CancellationError() }
        let fetched = page.events
        try await commit { current in
            var next = current
            let inside = Set(current.locations.filter { bounds.contains($0.coordinate) }.map(\.id))
            var byID: [String: CommunityEvent] = [:]
            for event in current.communityEvents where !inside.contains(event.ecopontoID) {
                byID[event.id] = event
            }
            for event in fetched { byID[event.id] = event }
            next.communityEvents = byID.values.filter {
                now.timeIntervalSince($0.serverTimestamp) <= CommunityIssuePolicy.expiry + 24 * 60 * 60
            }
            next.communityEventAreas.removeAll { bounds.contains($0.bounds) }
            next.communityEventAreas.append(CachedArea(bounds: bounds, syncedAt: now, locationIDs: []))
            if next.communityEventAreas.count > 32 {
                next.communityEventAreas.sort { $0.accessedAt < $1.accessedAt }
                next.communityEventAreas.removeFirst(next.communityEventAreas.count - 32)
            }
            return next
        }
    }

    public func inflightReportWaiters(_ request: IssueSubmissionRequest) async -> Int {
        await reportGate.inflightWaiters(for: IssueReportKey(ecopontoID: request.ecopontoID, issue: request.issue))
    }

    public func submitReport(_ request: IssueSubmissionRequest) async throws -> CommunityEvent {
        let client = self.client
        let event = try await reportGate.submit(request) { request in
            try await client.submitReport(request)
        }
        try await applyConfirmed(event)
        return event
    }
    public func submitResolution(_ request: IssueResolutionRequest) async throws -> CommunityEvent {
        let event = try await client.submitResolution(request)
        try await applyConfirmed(event)
        return event
    }
    private func applyConfirmed(_ event: CommunityEvent) async throws {
        try await commit(keepOnWriteFailure: true) { value in
            var next = value
            next.communityEvents.removeAll { $0.id == event.id }
            next.communityEvents.append(event)
            return next
        }
    }
    public func refreshFavourite(id: String, now: Date) async {
        await refreshFavourites([id], now: now)
    }

    /// Refreshes favourites in batches of 50. Ids already present on a fresh tile are skipped.
    public func refreshFavourites(_ ids: [String], now: Date, force: Bool = false) async {
        var seen = Set<String>()
        var pending: [String] = []
        for id in ids where seen.insert(id).inserted {
            // A retired three-part id makes the API reject the whole ids batch.
            if LocationIDStyle.isLegacySourceKey(id) { continue }
            if isFreshFromTile(id, now: now) { continue }
            if !force, let last = favouriteFetchedAt[id],
               now.timeIntervalSince(last) >= 0, now.timeIntervalSince(last) < MapTilePolicy.freshness {
                continue
            }
            pending.append(id)
        }
        pending.sort()
        guard !pending.isEmpty else { return }
        if !force, let retryAfter, now < retryAfter { return }
        var index = 0
        while index < pending.count {
            let end = min(index + MapTilePolicy.favouriteBatchLimit, pending.count)
            let batch = Array(pending[index..<end])
            index = end
            do {
                let result = try await client.fetchLocations(ids: batch)
                let locations = result.locations
                let missing = Set(result.missing)
                try await commit { current in
                    var next = current
                    var all = Dictionary(next.locations.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
                    for location in locations {
                        all[location.id] = location
                        next.removedLocationIDs.remove(location.id)
                    }
                    for id in missing {
                        next.removedLocationIDs.insert(id)
                        all.removeValue(forKey: id)
                    }
                    LocationIdentityCrosswalk.apply(
                        existing: current.locations,
                        fetched: locations,
                        to: &next,
                        locations: &all
                    )
                    next.locations = Array(all.values)
                    return next
                }
                for id in batch { favouriteFetchedAt[id] = now }
            } catch is CancellationError {
                return
            } catch {
                noteFailure(error, now: now)
                return
            }
        }
    }

    private func accepted(_ location: Ecoponto, in bounds: GeographicBounds, tile: SlippyTileCoordinate) -> Bool {
        location.coordinate.isValid && (bounds.contains(location.coordinate) || tile.bounds.contains(location.coordinate))
    }

    private func isFresh(_ tile: SlippyTileCoordinate, now: Date) -> Bool {
        guard let area = snapshot.cachedAreas.first(where: { $0.tile == tile }) else { return false }
        let age = now.timeIntervalSince(area.syncedAt)
        return age >= 0 && age < MapTilePolicy.freshness
    }

    private func isFreshFromTile(_ id: String, now: Date) -> Bool {
        snapshot.cachedAreas.contains { area in
            guard area.tile != nil, area.locationIDs.contains(id) else { return false }
            let age = now.timeIntervalSince(area.syncedAt)
            return age >= 0 && age < MapTilePolicy.freshness
        }
    }

    private func isBBoxFresh(_ bounds: GeographicBounds, now: Date) -> Bool {
        snapshot.cachedAreas.contains { area in
            guard area.tile == nil else { return false }
            let age = now.timeIntervalSince(area.syncedAt)
            return area.bounds.contains(bounds) && age >= 0 && age < MapTilePolicy.freshness
        }
    }

    private func touchBBox(_ bounds: GeographicBounds, now: Date) {
        for index in snapshot.cachedAreas.indices where snapshot.cachedAreas[index].tile == nil && snapshot.cachedAreas[index].bounds.contains(bounds) {
            snapshot.cachedAreas[index].accessedAt = now
            let areaBounds = snapshot.cachedAreas[index].bounds
            if let workingIndex = working.cachedAreas.firstIndex(where: { $0.tile == nil && $0.bounds == areaBounds }) {
                working.cachedAreas[workingIndex].accessedAt = now
            }
        }
    }

    private func isEventAreaFresh(_ bounds: GeographicBounds, now: Date) -> Bool {
        snapshot.communityEventAreas.contains { area in
            let age = now.timeIntervalSince(area.syncedAt)
            return area.bounds.contains(bounds) && age >= 0 && age < MapTilePolicy.freshness
        }
    }

    private func touch(_ tiles: [SlippyTileCoordinate], now: Date) {
        for index in snapshot.cachedAreas.indices where tiles.contains(where: { snapshot.cachedAreas[index].tile == $0 }) {
            snapshot.cachedAreas[index].accessedAt = now
            let tile = snapshot.cachedAreas[index].tile
            if let workingIndex = working.cachedAreas.firstIndex(where: { $0.tile == tile }) {
                working.cachedAreas[workingIndex].accessedAt = now
            }
        }
    }

    private func touchEvents(_ bounds: GeographicBounds, now: Date) {
        for index in snapshot.communityEventAreas.indices where snapshot.communityEventAreas[index].bounds.contains(bounds) {
            snapshot.communityEventAreas[index].accessedAt = now
            let areaBounds = snapshot.communityEventAreas[index].bounds
            if let workingIndex = working.communityEventAreas.firstIndex(where: { $0.bounds == areaBounds }) {
                working.communityEventAreas[workingIndex].accessedAt = now
            }
        }
    }

    private func noteFailure(_ error: Error, now: Date) {
        let mapped: ReciclarAPIError
        let header: TimeInterval?
        if let api = error as? ReciclarAPIError {
            switch api {
            case .rateLimited(let message, let retry):
                mapped = .rateLimited(message, retryAfter: retry)
                header = retry
                lastRefreshError = message
            case .serviceUnavailable(let message, let retry):
                mapped = .serviceUnavailable(message, retryAfter: retry)
                header = retry
                lastRefreshError = message
            default:
                mapped = .unavailable
                header = nil
                lastRefreshError = "Não foi possível atualizar esta zona. A informação guardada continua disponível."
            }
        } else {
            mapped = .unavailable
            header = nil
            lastRefreshError = "Não foi possível atualizar esta zona. A informação guardada continua disponível."
        }
        let delay = RefreshBackoff.delay(step: backoffStep, retryAfter: header)
        backoffStep = min(backoffStep + 1, 8)
        retryAfter = now.addingTimeInterval(delay)
        blockedError = mapped
    }

    // Serialize transforms across actor reentrancy. Disk writes debounce separately.
    private func commit(keepOnWriteFailure: Bool = false, _ transform: @escaping @Sendable (LocationSnapshot) throws -> LocationSnapshot) async throws {
        let previous = applyTail
        let stage = Task { () throws -> Void in
            if let previous { _ = await previous.value }
            try self.apply(transform)
        }
        applyTail = Task { _ = try? await stage.value }
        try await stage.value
        try await waitForDurability(keepOnWriteFailure: keepOnWriteFailure)
    }

    private func apply(_ transform: @Sendable (LocationSnapshot) throws -> LocationSnapshot) throws {
        var next = try transform(working)
        next.locations.sort { $0.id < $1.id }
        next.communityEvents.sort { $0.id < $1.id }
        working = next
        dirty = true
    }

    private func waitForDurability(keepOnWriteFailure: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task {
                await self.enqueueSave(SaveWaiter(
                    keepOnWriteFailure: keepOnWriteFailure,
                    continuation: continuation
                ))
            }
        }
    }

    private func enqueueSave(_ waiter: SaveWaiter) async {
        saveWaiters.append(waiter)
        guard !saveQueued else { return }
        saveQueued = true
        await drainSaves()
    }

    private func drainSaves() async {
        do {
            try await Task.sleep(nanoseconds: Self.diskCoalesceNanoseconds)
            while true {
                dirty = false
                let next = working
                try await store.save(next)
                if dirty { continue }
                publish(next)
                resumeSaves(nil)
                return
            }
        } catch {
            resumeSaves(error)
        }
    }

    private func resumeSaves(_ error: Error?) {
        let waiters = saveWaiters
        saveWaiters.removeAll()
        saveQueued = false
        if let error {
            if waiters.contains(where: \.keepOnWriteFailure) {
                publish(working)
                lastRefreshError = "O reporte foi confirmado, mas não foi possível guardá-lo neste aparelho."
            } else {
                working = rollback
            }
            for waiter in waiters {
                if waiter.keepOnWriteFailure {
                    waiter.continuation.resume()
                } else {
                    waiter.continuation.resume(throwing: error)
                }
            }
            return
        }
        for waiter in waiters {
            waiter.continuation.resume()
        }
    }

    private func publish(_ next: LocationSnapshot) {
        let changed = snapshot.locations != next.locations || snapshot.communityEvents != next.communityEvents
            || Set(snapshot.cachedAreas.flatMap(\.locationIDs)) != Set(next.cachedAreas.flatMap(\.locationIDs))
        snapshot = next
        rollback = next
        if changed { revision += 1 }
    }

}

private struct SaveWaiter: Sendable {
    var keepOnWriteFailure: Bool
    var continuation: CheckedContinuation<Void, Error>
}

private struct CacheByteLedger {
    var total: Int

    static func measure(_ snapshot: LocationSnapshot) -> CacheByteLedger {
        CacheByteLedger(total: CacheByteEstimate.total(of: snapshot))
    }

    mutating func removeArea(_ area: CachedArea, remaining: Int) {
        total -= CacheByteEstimate.bytes(of: area)
        total -= Self.commaDelta(removed: 1, remaining: remaining)
    }

    mutating func removeLocations(_ locations: [Ecoponto], remaining: Int) {
        guard !locations.isEmpty else { return }
        total -= locations.reduce(0) { $0 + CacheByteEstimate.bytes(of: $1) }
        total -= Self.commaDelta(removed: locations.count, remaining: remaining)
    }

    mutating func removeEvents(_ events: [CommunityEvent], remaining: Int) {
        guard !events.isEmpty else { return }
        total -= events.reduce(0) { $0 + CacheByteEstimate.bytes(of: $1) }
        total -= Self.commaDelta(removed: events.count, remaining: remaining)
    }

    private static func commaDelta(removed: Int, remaining: Int) -> Int {
        guard removed > 0 else { return 0 }
        if remaining > 0 { return removed }
        return removed - 1
    }
}

/// Approximate JSON size of a snapshot. Nil optionals are omitted, matching synthesized Codable.
private enum CacheByteEstimate {
    static func total(of snapshot: LocationSnapshot) -> Int {
        var fields: [(String, Int)] = [
            ("cachedAreas", array(snapshot.cachedAreas.map(bytes(of:)))),
            ("locations", array(snapshot.locations.map(bytes(of:)))),
            ("communityEvents", array(snapshot.communityEvents.map(bytes(of:)))),
            ("communityEventAreas", array(snapshot.communityEventAreas.map(bytes(of:)))),
            ("isFixtureData", bool(snapshot.isFixtureData)),
            ("removedLocationIDs", array(snapshot.removedLocationIDs.map(string))),
        ]
        if let value = snapshot.lastSuccessfulSync { fields.append(("lastSuccessfulSync", date(value))) }
        if let value = snapshot.syncToken { fields.append(("syncToken", string(value))) }
        if let value = snapshot.coverageNote { fields.append(("coverageNote", string(value))) }
        return object(fields)
    }

    static func bytes(of location: Ecoponto) -> Int {
        var fields: [(String, Int)] = [
            ("id", string(location.id)),
            ("coordinate", bytes(of: location.coordinate)),
            ("containers", array(location.containers.map(bytes(of:)))),
            ("provenance", object([("label", string(location.provenance.label))])),
        ]
        if let value = location.concessionaireID { fields.append(("concessionaireID", string(value))) }
        if let value = location.district { fields.append(("district", string(value))) }
        if let value = location.municipality { fields.append(("municipality", string(value))) }
        if let value = location.parish { fields.append(("parish", string(value))) }
        if let value = location.locality { fields.append(("locality", string(value))) }
        if let value = location.address { fields.append(("address", string(value))) }
        if let value = location.locationDescription { fields.append(("locationDescription", string(value))) }
        return object(fields)
    }

    static func bytes(of event: CommunityEvent) -> Int {
        object([
            ("id", string(event.id)),
            ("ecopontoID", string(event.ecopontoID)),
            ("issue", string(event.issue.rawValue)),
            ("kind", string(event.kind.rawValue)),
            ("serverTimestamp", date(event.serverTimestamp)),
        ])
    }

    static func bytes(of area: CachedArea) -> Int {
        var fields: [(String, Int)] = [
            ("bounds", bytes(of: area.bounds)),
            ("syncedAt", date(area.syncedAt)),
            ("accessedAt", date(area.accessedAt)),
            ("locationIDs", array(area.locationIDs.map(string))),
        ]
        if let value = area.tileZoom { fields.append(("tileZoom", int(value))) }
        if let value = area.tileX { fields.append(("tileX", int(value))) }
        if let value = area.tileY { fields.append(("tileY", int(value))) }
        return object(fields)
    }

    private static func bytes(of container: Container) -> Int {
        var fields: [(String, Int)] = [
            ("id", string(container.id)),
            ("category", object([
                ("id", object([("rawValue", string(container.category.id.rawValue))])),
                ("name", string(container.category.name)),
            ])),
        ]
        if let value = container.colorToken { fields.append(("colorToken", string(value))) }
        if let value = container.volumeLitres { fields.append(("volumeLitres", int(value))) }
        if let value = container.typeDescription { fields.append(("typeDescription", string(value))) }
        if let value = container.code { fields.append(("code", string(value))) }
        if let value = container.fillReading {
            fields.append(("fillReading", object([
                ("percentFull", int(value.percentFull)),
                ("recordedAt", date(value.recordedAt)),
            ])))
        }
        if let value = container.lastCollectionAt { fields.append(("lastCollectionAt", date(value))) }
        if let value = container.lastWashingAt { fields.append(("lastWashingAt", date(value))) }
        return object(fields)
    }

    private static func bytes(of coordinate: Coordinate) -> Int {
        object([
            ("latitude", double(coordinate.latitude)),
            ("longitude", double(coordinate.longitude)),
        ])
    }

    private static func bytes(of bounds: GeographicBounds) -> Int {
        object([
            ("minLatitude", double(bounds.minLatitude)),
            ("maxLatitude", double(bounds.maxLatitude)),
            ("minLongitude", double(bounds.minLongitude)),
            ("maxLongitude", double(bounds.maxLongitude)),
        ])
    }

    private static func object(_ fields: [(String, Int)]) -> Int {
        var total = 2
        for (index, field) in fields.enumerated() {
            if index > 0 { total += 1 }
            total += field.0.utf8.count + 3 + field.1
        }
        return total
    }

    private static func array(_ items: [Int]) -> Int {
        var total = 2
        for (index, item) in items.enumerated() {
            if index > 0 { total += 1 }
            total += item
        }
        return total
    }

    private static func string(_ value: String) -> Int {
        var count = 2
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x22, 0x5C: count += 2
            case 0x00..<0x20, 0x80...: count += 6
            default: count += 1
            }
        }
        return count
    }

    private static func double(_ value: Double) -> Int {
        guard value.isFinite else { return 4 }
        if value == 0 { return 5 }
        let digits = Int(log10(Swift.max(abs(value), 1))) + 1
        return (value < 0 ? 1 : 0) + digits + 8
    }

    private static func int(_ value: Int) -> Int {
        if value == 0 { return 1 }
        var count = value < 0 ? 1 : 0
        var magnitude = abs(value)
        while magnitude > 0 {
            count += 1
            magnitude /= 10
        }
        return count
    }

    private static func date(_ value: Date) -> Int {
        double(value.timeIntervalSinceReferenceDate)
    }

    private static func bool(_ value: Bool) -> Int {
        value ? 4 : 5
    }
}

public actor MapPreparationWorker {
    public init() {}
    public func prepare(_ locations: [Ecoponto]) -> (SpatialIndex, [WasteFilterChip]) {
        (SpatialIndex(locations: locations), WasteFilterChip.chips(from: locations))
    }
    public func items(index: SpatialIndex, bounds: GeographicBounds, latitudeSpan: Double,
                      filter: LocationFilter, now: Date) -> [MapPresentationItem] {
        guard bounds.maximumDimensionKilometres <= 24.1 else { return [] }
        return MapPresentationPolicy.items(from: index.locations(in: bounds), in: bounds,
                                           latitudeSpan: latitudeSpan, filter: filter, now: now)
    }

    public func nextFillBoundary(in locations: [Ecoponto], now: Date) -> Date {
        FreshnessSchedule.nextFillBoundary(locations: locations, now: now)
    }
}
