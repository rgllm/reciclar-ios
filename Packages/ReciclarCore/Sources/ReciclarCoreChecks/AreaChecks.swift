import Foundation
import ReciclarCore

func runAreaChecks() async -> [String] {
    var failures: [String] = []
    func check(_ value: Bool, _ message: String) { if !value { failures.append(message) } }
    let now = Date(timeIntervalSince1970: 1_789_000_000)
    let point = Coordinate(latitude: 41.55, longitude: -8.4)
    let bounds = GeographicBounds(center: point, latitudeDelta: 0.03, longitudeDelta: 0.03)
    let inner = GeographicBounds(center: point, latitudeDelta: 0.01, longitudeDelta: 0.01)
    let location = Ecoponto(id: "one", coordinate: point, containers: [], provenance: .developmentFixture)
    func page(_ rows: [Ecoponto], more: Bool = false, cursor: String? = nil, token: String = "v1") -> LocationSyncPage {
        LocationSyncPage(locations: rows, communityEvents: [], isCompleteReplacement: false,
                         isFixtureData: true, hasMore: more, nextCursor: cursor, syncToken: token)
    }
    let client = MockReciclarClient(clock: { now })
    let store = InMemorySnapshotStore()
    let repo = AreaRepository(client: client, store: store)
    await client.setPages([page([location])])
    do {
        try await repo.refreshArea(bounds, now: now)
        check(await repo.isCovered(inner), "area covers its inner viewport")
        check(await repo.currentSnapshot().syncToken == nil, "area cannot establish global sync")
        let calls = await client.tileCalls
        let events = await client.eventCalls
        let revision = await repo.revision
        try await repo.refreshArea(inner, now: now.addingTimeInterval(60))
        check(await client.tileCalls == calls, "fresh covered tiles avoid network")
        check(await client.eventCalls == events, "fresh event coverage avoids network")
        check(await repo.revision == revision, "freshness check does not revise map data")
        try await repo.refreshArea(bounds, now: now.addingTimeInterval(901))
        check(await client.tileCalls == calls + 1, "stale tile refreshes")
        check(await client.eventCalls == events + 1, "stale events refresh separately")
        let restored = AreaRepository(client: client, store: store)
        await restored.loadCache()
        check(await restored.isCovered(inner), "area coverage survives cache reload")
        check(await restored.currentSnapshot().locations == [location], "cached location survives reload")
    } catch { failures.append("successful area refresh: \(error)") }

    let before = await repo.currentSnapshot()
    await store.setAreaFailSave(true)
    await client.setPages([page([])])
    do { try await repo.refreshArea(bounds, now: now, force: true); failures.append("failed save should throw") }
    catch { check(await repo.currentSnapshot() == before, "failed save preserves complete previous area") }
    await store.setAreaFailSave(false)
    await client.setPages([page([], more: true, cursor: "1"), page([], token: "v2")])
    do { try await repo.refreshArea(bounds, now: now, force: true); failures.append("mixed version should throw") }
    catch { check(await repo.currentSnapshot() == before, "mixed versions preserve cache") }
    await client.setPages([page([], more: true, cursor: "1"), page([], more: true, cursor: "1")])
    do { try await repo.refreshArea(bounds, now: now, force: true); failures.append("cursor cycle should throw") }
    catch { check(await repo.currentSnapshot() == before, "pagination cycle preserves cache") }
    await client.setPages([page([])])
    do {
        try await repo.refreshArea(bounds, now: now, force: true)
        check(await repo.isCovered(bounds), "completed empty area remains cached")
        check(await repo.currentSnapshot().locations.isEmpty, "absent records removed from local area")
        check(await repo.currentSnapshot().removedLocationIDs.isEmpty, "absence is not a global deletion")
    } catch { failures.append("empty area: \(error)") }

    // A confirmed server report must remain successful even if local persistence fails.
    await store.setAreaFailSave(true)
    do {
        let event = try await repo.submitReport(IssueSubmissionRequest(ecopontoID: "one", issue: .vandalised))
        check(await repo.currentSnapshot().communityEvents.contains(event), "confirmed report survives failed disk write in memory")
    } catch { failures.append("confirmed report must not prompt duplicate submission") }
    await store.setAreaFailSave(false)

    // Migration retains the original file and cached timestamps until new persistence succeeds.
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    do {
        let legacy = DiskSnapshotStore(directory: directory)
        try await legacy.save(before)
        let areaStore = DiskSnapshotStore(directory: directory, areaCache: true)
        let imported = try await areaStore.load()
        check(imported == before, "legacy cache imports without resetting timestamps")
        try await areaStore.save(before)
        check(FileManager.default.fileExists(atPath: directory.appendingPathComponent("location-cache.json").path), "migration retains old cache")
        check(try await areaStore.load() == before, "new area cache reloads")
        check(try await areaStore.load()?.cachedAreas.contains { $0.tile != nil } == true, "tile identity survives cache reload")
    } catch { failures.append("disk migration: \(error)") }

    let backoffClient = MockReciclarClient(clock: { now })
    let backoffRepo = AreaRepository(client: backoffClient, store: InMemorySnapshotStore())
    await backoffClient.setNextError(.rateLimited("Demasiados reportes neste momento. Tente mais tarde.", retryAfter: 90))
    do {
        try await backoffRepo.refreshArea(bounds, now: now, force: true)
        failures.append("429 should fail the refresh")
    } catch let error as ReciclarAPIError {
        if case .rateLimited = error {} else { failures.append("429 is distinct from other failures") }
        let calls = await backoffClient.tileCalls
        do {
            try await backoffRepo.refreshArea(bounds, now: now.addingTimeInterval(30))
            failures.append("retry during Retry-After should not reach the network")
        } catch let blocked as ReciclarAPIError {
            if case .rateLimited = blocked {} else { failures.append("blocked 429 stays a rate limit") }
            check(await backoffClient.tileCalls == calls, "429 backoff avoids requests")
        } catch { failures.append("429 backoff: \(error)") }
        do {
            try await backoffRepo.refreshArea(bounds, now: now.addingTimeInterval(91))
            check(await backoffClient.tileCalls == calls + 1, "refresh after Retry-After hits the network once")
        } catch { failures.append("refresh after Retry-After: \(error)") }
    } catch { failures.append("429: \(error)") }

    let unavailableClient = MockReciclarClient(clock: { now })
    let unavailableRepo = AreaRepository(client: unavailableClient, store: InMemorySnapshotStore())
    await unavailableClient.setNextError(.serviceUnavailable("Não foi possível carregar esta zona. Tenta novamente.", retryAfter: 10))
    do {
        try await unavailableRepo.refreshArea(bounds, now: now, force: true)
        failures.append("503 should fail the refresh")
    } catch let error as ReciclarAPIError {
        if case .serviceUnavailable = error {} else { failures.append("503 is distinct from 429") }
        let calls = await unavailableClient.tileCalls
        do {
            try await unavailableRepo.refreshArea(bounds, now: now.addingTimeInterval(10))
            failures.append("503 should still be backing off at 10 s")
        } catch let blocked as ReciclarAPIError {
            if case .serviceUnavailable = blocked {} else { failures.append("blocked 503 stays unavailable") }
            check(await unavailableClient.tileCalls == calls, "503 backoff avoids requests")
        } catch { failures.append("503 backoff: \(error)") }
        do {
            try await unavailableRepo.refreshArea(bounds, now: now.addingTimeInterval(31))
            check(await unavailableClient.tileCalls == calls + 1, "503 retries after the 30 s floor")
        } catch { failures.append("503 retry: \(error)") }
    } catch { failures.append("503: \(error)") }

    let favouriteClient = MockReciclarClient(clock: { now })
    let favouriteRepo = AreaRepository(client: favouriteClient, store: InMemorySnapshotStore())
    let inside = Ecoponto(id: "inside", coordinate: point, containers: [], provenance: .developmentFixture)
    let outsidePoint = Coordinate(latitude: 41.15, longitude: -8.6)
    let outside = Ecoponto(id: "outside", coordinate: outsidePoint, containers: [], provenance: .developmentFixture)
    await favouriteClient.setPages([page([inside])])
    await favouriteClient.setExtraLocations(["outside": outside])
    await favouriteClient.setGoneIDs(["missing-fav"])
    await favouriteRepo.protectFavourites(["inside", "outside", "missing-fav"])
    do {
        try await favouriteRepo.refreshArea(bounds, now: now)
        await favouriteRepo.refreshFavourites(["inside", "outside", "missing-fav"], now: now)
        let batches = await favouriteClient.idBatchCalls
        check(batches == [["missing-fav", "outside"]], "favourites skip ids already fresh from tiles")
        check(await favouriteRepo.currentSnapshot().location(id: "outside") != nil, "batched favourite is stored")
        check(await favouriteRepo.currentSnapshot().removedLocationIDs.contains("missing-fav"), "explicit missing id is removed")
        check(await favouriteRepo.currentSnapshot().location(id: "inside") != nil, "tile-fresh favourite stays")
        let calls = await favouriteClient.idBatchCalls.count
        await favouriteRepo.refreshFavourites(["inside", "outside"], now: now.addingTimeInterval(60), force: true)
        let forced = await favouriteClient.idBatchCalls
        check(forced.count == calls + 1 && forced.last == ["outside"], "forced refresh still skips the fresh tile")
    } catch { failures.append("favourite batches: \(error)") }

    let eventClient = MockReciclarClient(clock: { now })
    let eventRepo = AreaRepository(client: eventClient, store: InMemorySnapshotStore())
    await eventClient.setPages([page([location])])
    await eventClient.setScriptedEvents([
        CommunityEvent(id: "evt", ecopontoID: "one", issue: .vandalised, kind: .report, serverTimestamp: now)
    ])
    do {
        try await eventRepo.refreshArea(bounds, now: now)
        check(await eventRepo.currentSnapshot().communityEvents.map(\.id) == ["evt"], "events come from the community endpoint")
        check(await eventClient.eventCalls == 1, "events are fetched once per refresh")
    } catch { failures.append("community events: \(error)") }

    let fallbackClient = MockReciclarClient(clock: { now })
    let fallbackRepo = AreaRepository(client: fallbackClient, store: InMemorySnapshotStore())
    var bboxPage = page([location])
    bboxPage.communityEvents = [CommunityEvent(id: "from-bbox", ecopontoID: "one", issue: .vandalised, kind: .report, serverTimestamp: now)]
    await fallbackClient.setPages([bboxPage])
    await fallbackClient.setNextError(.notFound)
    do {
        try await fallbackRepo.refreshArea(bounds, now: now)
        check(await fallbackClient.tileCalls == 1, "a tile 404 tries the tile route once")
        check(await fallbackClient.snapshotCalls == 1, "tile 404 falls back to the bbox query")
        check(await fallbackClient.eventCalls == 0, "bbox fallback does not also call community-events")
        check(await fallbackRepo.currentSnapshot().locations == [location], "bbox fallback stores the viewport")
        check(await fallbackRepo.currentSnapshot().communityEvents.map(\.id) == ["from-bbox"], "bbox fallback keeps events from the area payload")
        check(await fallbackRepo.isCovered(inner), "bbox fallback covers the viewport")
        let tiles = await fallbackClient.tileCalls
        let snapshots = await fallbackClient.snapshotCalls
        try await fallbackRepo.refreshArea(inner, now: now.addingTimeInterval(60))
        check(await fallbackClient.tileCalls == tiles, "fresh bbox fallback does not retry tiles")
        check(await fallbackClient.snapshotCalls == snapshots, "fresh bbox fallback avoids another area request")
    } catch { failures.append("tile 404 fallback: \(error)") }

    let farPoint = Coordinate(latitude: 38.754, longitude: -9.053)
    let farBounds = GeographicBounds(center: farPoint, latitudeDelta: 0.002, longitudeDelta: 0.002)
    let nearBounds = GeographicBounds(center: point, latitudeDelta: 0.002, longitudeDelta: 0.002)
    let nearLocation = Ecoponto(id: "near", coordinate: point, containers: [], provenance: .developmentFixture)
    let oldLocation = Ecoponto(id: "old", coordinate: farPoint, containers: [], provenance: .developmentFixture)
    let favourite = Ecoponto(id: "fav", coordinate: farPoint, containers: [], provenance: .developmentFixture)
    let limitClient = MockReciclarClient(clock: { now })
    let limited = AreaRepository(client: limitClient, store: InMemorySnapshotStore(), byteLimit: 1)
    await limited.protectFavourites(["fav"])
    do {
        let nearTiles = try SlippyMapTiles.covering(nearBounds, zoom: MapTilePolicy.zoom)
        let farTiles = try SlippyMapTiles.covering(farBounds, zoom: MapTilePolicy.zoom)
        check(nearTiles.count == 1 && farTiles.count == 1 && nearTiles != farTiles, "eviction fixture uses two distinct tiles")
        await limitClient.setPages([page([oldLocation, favourite])])
        try await limited.refreshArea(farBounds, now: now)
        await limitClient.setPages([page([nearLocation])])
        try await limited.refreshArea(nearBounds, now: now.addingTimeInterval(1))
        let kept = await limited.currentSnapshot()
        check(kept.location(id: "near") != nil, "current area survives the cache limit")
        check(kept.location(id: "old") == nil, "oldest area is evicted to stay under the limit")
        check(kept.location(id: "fav") != nil, "favourite survives area eviction")
        if nearTiles.count == 1, farTiles.count == 1 {
            check(kept.cachedAreas.contains { $0.tile == nearTiles[0] }, "current tile stays cached")
            check(!kept.cachedAreas.contains { $0.tile == farTiles[0] }, "evicted tile record is removed")
        }
    } catch { failures.append("cache limit: \(error)") }

    let stable = Coordinate(latitude: 41.5, longitude: -8.5)
    let legacyID = "legacy:op:1"
    let publicID = "rc_0123456789abcdef0123"
    let legacy = Ecoponto(id: legacyID, coordinate: stable, containers: [], provenance: .developmentFixture)
    let published = Ecoponto(id: publicID, coordinate: stable, containers: [], provenance: .developmentFixture)
    let drifted = Ecoponto(
        id: publicID,
        coordinate: Coordinate(latitude: stable.latitude + 0.0000004, longitude: stable.longitude),
        containers: [],
        provenance: .developmentFixture
    )
    let moved = Ecoponto(
        id: publicID,
        coordinate: Coordinate(latitude: stable.latitude + 0.00002, longitude: stable.longitude),
        containers: [],
        provenance: .developmentFixture
    )
    let otherLegacy = Ecoponto(id: "legacy:op:2", coordinate: stable, containers: [], provenance: .developmentFixture)
    let secondPublic = Ecoponto(id: "rc_aaaaaaaaaaaaaaaaaaaa", coordinate: stable, containers: [], provenance: .developmentFixture)
    check(!LocationIDStyle.isLegacySourceKey(publicID), "public id is not a retired id")
    check(LocationIDStyle.isLegacySourceKey(legacyID), "retired id has three parts")
    check(!LocationIDStyle.isLegacySourceKey("legacy:op"), "short id stays opaque")
    check(!LocationIDStyle.isLegacySourceKey("legacy:op:1:more"), "extra colon stays opaque")
    check(
        LocationIdentityCrosswalk.renames(existing: [legacy], fetched: [published]) == [legacyID: publicID],
        "same coordinate retargets one legacy id"
    )
    check(
        LocationIdentityCrosswalk.renames(existing: [legacy], fetched: [drifted]) == [legacyID: publicID],
        "sub-metre drift still matches"
    )
    check(LocationIdentityCrosswalk.renames(existing: [legacy], fetched: [moved]).isEmpty, "a moved coordinate is not the same ecoponto")
    check(
        LocationIdentityCrosswalk.renames(existing: [legacy, otherLegacy], fetched: [published]).isEmpty,
        "two legacy ids at one coordinate stay unmatched"
    )
    check(
        LocationIdentityCrosswalk.renames(existing: [legacy], fetched: [published, secondPublic]).isEmpty,
        "two public ids at one coordinate stay unmatched"
    )

    let crossClient = MockReciclarClient(clock: { now })
    let crossStore = InMemorySnapshotStore()
    let crossRepo = AreaRepository(client: crossClient, store: crossStore)
    let crossBounds = GeographicBounds(center: stable, latitudeDelta: 0.03, longitudeDelta: 0.03)
    await crossClient.setPages([page([legacy])])
    await crossClient.setScriptedEvents([
        CommunityEvent(id: "evt-legacy", ecopontoID: legacyID, issue: .vandalised, kind: .report, serverTimestamp: now)
    ])
    await crossRepo.protectFavourites([legacyID, "legacy:op:9"])
    do {
        try await crossRepo.refreshArea(crossBounds, now: now)
        check(await crossRepo.currentSnapshot().location(id: legacyID) != nil, "legacy id is cached before the cutover")
        await crossClient.setPages([page([published])])
        await crossClient.setScriptedEvents([
            CommunityEvent(id: "evt-public", ecopontoID: publicID, issue: .vandalised, kind: .report, serverTimestamp: now)
        ])
        try await crossRepo.refreshArea(crossBounds, now: now.addingTimeInterval(901), force: true)
        let migrated = await crossRepo.currentSnapshot()
        check(migrated.location(id: legacyID) == nil, "legacy location is replaced")
        check(migrated.location(id: publicID) != nil, "public location is stored")
        check(migrated.identityRenames == [legacyID: publicID], "rename is kept for favourites")
        check(!migrated.communityEvents.contains { $0.ecopontoID == legacyID }, "events leave the legacy id")
        check(migrated.communityEvents.contains { $0.ecopontoID == publicID }, "events follow the public id")
        check(!migrated.cachedAreas.contains { $0.locationIDs.contains(legacyID) }, "tile membership drops the legacy id")
        let callsBefore = await crossClient.idBatchCalls.count
        await crossRepo.refreshFavourites([legacyID, "legacy:op:9", publicID], now: now.addingTimeInterval(901), force: true)
        check(await crossClient.idBatchCalls.count == callsBefore, "retired ids are not sent and the fresh public id is skipped")
        let pending = AreaRepository(client: crossClient, store: crossStore)
        await pending.loadCache()
        check(await pending.currentSnapshot().identityRenames == [legacyID: publicID], "rename survives relaunch")
        let favStore = InMemoryFavouritesStore(records: [
            FavouriteRecord(ecopontoID: legacyID, savedAt: now),
            FavouriteRecord(ecopontoID: publicID, savedAt: now.addingTimeInterval(10)),
        ])
        let favourites = FavouritesStore(persistence: favStore)
        await favourites.load()
        await favourites.replace(legacyID, with: publicID)
        check(await favStore.records == [FavouriteRecord(ecopontoID: publicID, savedAt: now)], "favourite keeps the earlier save")
        try await crossRepo.clearIdentityRenames([legacyID])
        check(await crossRepo.currentSnapshot().identityRenames.isEmpty, "adopted renames are cleared")
        let reloaded = AreaRepository(client: crossClient, store: crossStore)
        await reloaded.loadCache()
        check(await reloaded.currentSnapshot().location(id: publicID) != nil, "public id survives reload")
        check(await reloaded.currentSnapshot().location(id: legacyID) == nil, "legacy id stays gone after reload")
    } catch { failures.append("identity crosswalk: \(error)") }

    let ambiguousClient = MockReciclarClient(clock: { now })
    let ambiguousRepo = AreaRepository(client: ambiguousClient, store: InMemorySnapshotStore())
    await ambiguousRepo.protectFavourites([legacyID, "legacy:op:2"])
    await ambiguousClient.setPages([page([legacy, otherLegacy])])
    do {
        try await ambiguousRepo.refreshArea(crossBounds, now: now)
        await ambiguousClient.setPages([page([published])])
        try await ambiguousRepo.refreshArea(crossBounds, now: now.addingTimeInterval(901), force: true)
        let kept = await ambiguousRepo.currentSnapshot()
        check(kept.location(id: legacyID) != nil, "ambiguous legacy favourite stays")
        check(kept.location(id: "legacy:op:2") != nil, "second legacy favourite stays")
        check(kept.location(id: publicID) != nil, "public location is stored beside an ambiguous pair")
        check(kept.identityRenames.isEmpty, "ambiguous coordinates are not merged")
    } catch { failures.append("ambiguous identity: \(error)") }

    let bothClient = MockReciclarClient(clock: { now })
    let bothRepo = AreaRepository(client: bothClient, store: InMemorySnapshotStore())
    await bothClient.setPages([page([legacy, published])])
    do {
        try await bothRepo.refreshArea(crossBounds, now: now)
        let kept = await bothRepo.currentSnapshot()
        check(kept.location(id: legacyID) == nil, "a mixed response keeps the public id only")
        check(kept.location(id: publicID) != nil, "a mixed response stores the public id")
        check(kept.identityRenames == [legacyID: publicID], "a mixed response records the rename")
    } catch { failures.append("mixed identity response: \(error)") }
    return failures
}

extension InMemorySnapshotStore {
    func setAreaFailSave(_ value: Bool) { failSave = value }
}
