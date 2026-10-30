import Foundation

public protocol SnapshotStore: Sendable {
    func load() async throws -> LocationSnapshot?
    func save(_ snapshot: LocationSnapshot) async throws
}

public protocol FavouritesPersisting: Sendable {
    func load() async throws -> [FavouriteRecord]
    func save(_ records: [FavouriteRecord]) async throws
}

public protocol StatsPersisting: Sendable {
    func load() async throws -> CachedCatalogStatistics?
    func save(_ cache: CachedCatalogStatistics) async throws
}

public actor DiskSnapshotStore: SnapshotStore {
    private let fileURL: URL
    private var legacyFileURL: URL?
    private let encoder = JSONEncoder()
    private var pendingSnapshot: LocationSnapshot?
    private var flushWaiters: [CheckedContinuation<Void, Error>] = []

    public init(directory: URL, areaCache: Bool = false) {
        fileURL = directory.appendingPathComponent(areaCache ? "area-cache.json" : "location-cache.json")
        legacyFileURL = areaCache ? directory.appendingPathComponent("location-cache.json") : nil
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = []
    }

    public func load() async throws -> LocationSnapshot? {
        let primary = fileURL
        let legacy = legacyFileURL
        // Decode off this actor. A MainActor caller waiting on load() must not
        // run JSONDecoder on the main thread before the map can draw.
        return try await Task.detached(priority: .userInitiated) {
            try Self.readSnapshot(primary: primary, legacy: legacy)
        }.value
    }

    private static func readSnapshot(primary: URL, legacy: URL?) throws -> LocationSnapshot? {
        let manager = FileManager()
        let source = manager.fileExists(atPath: primary.path) ? primary : (legacy ?? primary)
        guard manager.fileExists(atPath: source.path) else { return nil }
        do {
            let data = try Data(contentsOf: source)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(LocationSnapshot.self, from: data)
        } catch {
            throw CacheError.unreadable
        }
    }

    public func save(_ snapshot: LocationSnapshot) async throws {
        pendingSnapshot = snapshot
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { await self.enqueue(continuation) }
        }
    }

    private func enqueue(_ continuation: CheckedContinuation<Void, Error>) async {
        flushWaiters.append(continuation)
        guard flushWaiters.count == 1 else { return }
        await pump()
    }

    /// Overlapping saves encode once. A save that arrives before the encode replaces the payload.
    private func pump() async {
        do {
            await Task.yield()
            while true {
                guard let next = pendingSnapshot else { break }
                pendingSnapshot = nil
                await Task.yield()
                if pendingSnapshot != nil { continue }
                try FileStore.writeAtomically(try encoder.encode(next), to: fileURL)
            }
            resumeFlush(nil)
        } catch {
            pendingSnapshot = nil
            resumeFlush(error)
        }
    }

    private func resumeFlush(_ error: Error?) {
        let waiters = flushWaiters
        flushWaiters.removeAll()
        for waiter in waiters {
            if let error {
                waiter.resume(throwing: error)
            } else {
                waiter.resume()
            }
        }
    }
}

public actor DiskFavouritesStore: FavouritesPersisting {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("favourites.json")
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() async throws -> [FavouriteRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([FavouriteRecord].self, from: data)
    }

    public func save(_ records: [FavouriteRecord]) async throws {
        try FileStore.writeAtomically(try encoder.encode(records), to: fileURL)
    }
}

public actor DiskStatsStore: StatsPersisting {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("stats-cache.json")
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() async throws -> CachedCatalogStatistics? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(CachedCatalogStatistics.self, from: data)
        } catch {
            throw CacheError.unreadable
        }
    }

    public func save(_ cache: CachedCatalogStatistics) async throws {
        try FileStore.writeAtomically(try encoder.encode(cache), to: fileURL)
    }
}

public actor InMemorySnapshotStore: SnapshotStore {
    public var snapshot: LocationSnapshot?
    public var failSave = false

    public init(snapshot: LocationSnapshot? = nil) {
        self.snapshot = snapshot
    }

    public func load() async throws -> LocationSnapshot? { snapshot }

    public func save(_ snapshot: LocationSnapshot) async throws {
        if failSave { throw CacheError.unreadable }
        self.snapshot = snapshot
    }
}

public actor InMemoryFavouritesStore: FavouritesPersisting {
    public var records: [FavouriteRecord] = []

    public init(records: [FavouriteRecord] = []) {
        self.records = records
    }

    public func load() async throws -> [FavouriteRecord] { records }

    public func save(_ records: [FavouriteRecord]) async throws {
        self.records = records
    }
}

public actor InMemoryStatsStore: StatsPersisting {
    public var cache: CachedCatalogStatistics?

    public init(cache: CachedCatalogStatistics? = nil) {
        self.cache = cache
    }

    public func load() async throws -> CachedCatalogStatistics? { cache }

    public func save(_ cache: CachedCatalogStatistics) async throws {
        self.cache = cache
    }
}

public enum CacheError: Error, Equatable, Sendable {
    case unreadable
}

enum FileStore {
    static func writeAtomically(_ data: Data, to fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let tempURL = directory.appendingPathComponent("\(UUID().uuidString).tmp")
        try data.write(to: tempURL, options: .atomic)
        #if os(Linux)
        // replaceItemAt deletes the destination, rewrites the temp with the old bytes, and throws.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: fileURL)
        #else
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        }
        #endif
    }
}

public actor FavouritesStore {
    private let persistence: any FavouritesPersisting
    private var records: [FavouriteRecord] = []

    public init(persistence: any FavouritesPersisting) {
        self.persistence = persistence
    }

    public func load() async {
        records = (try? await persistence.load()) ?? []
    }

    public func identifiers() -> [String] {
        records.map(\.ecopontoID)
    }

    public func contains(_ id: String) -> Bool {
        records.contains { $0.ecopontoID == id }
    }

    public func add(_ id: String, at date: Date) async {
        guard !contains(id) else { return }
        records.append(FavouriteRecord(ecopontoID: id, savedAt: date))
        try? await persistence.save(records)
    }

    public func remove(_ id: String) async {
        records.removeAll { $0.ecopontoID == id }
        try? await persistence.save(records)
    }

    /// Points a saved favourite at the public id of the same ecoponto. Keeps the original save date.
    public func replace(_ id: String, with newID: String) async {
        guard id != newID, let index = records.firstIndex(where: { $0.ecopontoID == id }) else { return }
        let savedAt = records[index].savedAt
        records.remove(at: index)
        if let existing = records.firstIndex(where: { $0.ecopontoID == newID }) {
            if records[existing].savedAt > savedAt {
                records[existing] = FavouriteRecord(ecopontoID: newID, savedAt: savedAt)
            }
        } else {
            records.append(FavouriteRecord(ecopontoID: newID, savedAt: savedAt))
        }
        try? await persistence.save(records)
    }

    public func toggle(_ id: String, at date: Date) async {
        if contains(id) {
            await remove(id)
        } else {
            await add(id, at: date)
        }
    }
}
