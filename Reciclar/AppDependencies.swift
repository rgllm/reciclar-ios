import ReciclarCore
import Foundation

struct AppDependencies: Sendable {
    var repository: AreaRepository
    var stats: StatsRepository
    var favourites: FavouritesStore
    var sortingCatalog: SortingCatalog
    var clock: @Sendable () -> Date

    static func live(fileManager: FileManager = .default) -> AppDependencies {
        let clock: @Sendable () -> Date = { Date() }
        let support = supportDirectory(fileManager: fileManager)
        LegacyInstallationIdentity.deletePersistedValues()
        let configuration = ReciclarAPIConfiguration(baseURL: resolvedBaseURL)
        let client = HTTPReciclarClient(configuration: configuration)
        return AppDependencies(
            repository: AreaRepository(
                client: client,
                store: DiskSnapshotStore(directory: support, areaCache: true),
                tileZoom: configuration.tileZoom
            ),
            stats: StatsRepository(
                client: client,
                store: DiskStatsStore(directory: support)
            ),
            favourites: FavouritesStore(
                persistence: DiskFavouritesStore(directory: support)
            ),
            sortingCatalog: .production,
            clock: clock
        )
    }

    static func preview() -> AppDependencies {
        let now = Date()
        let clock: @Sendable () -> Date = { now }
        let client = MockReciclarClient(clock: clock)
        return AppDependencies(
            repository: AreaRepository(
                client: client,
                store: InMemorySnapshotStore(snapshot: DevelopmentFixtures.snapshot(at: now))
            ),
            stats: StatsRepository(
                client: client,
                store: InMemoryStatsStore(),
                policy: SyncPolicy(interval: 15 * 60, maxAttempts: 1, baseDelayNanoseconds: 0)
            ),
            favourites: FavouritesStore(persistence: InMemoryFavouritesStore()),
            sortingCatalog: .development,
            clock: clock
        )
    }

    private static var resolvedBaseURL: URL {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["ECOPONTOS_API_BASE"],
           let url = URL(string: override) {
            return url
        }
        #endif
        return ReciclarAPIConfiguration.productionBaseURL
    }

    private static func supportDirectory(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent("Reciclar", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
