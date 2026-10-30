import Foundation

public actor StatsRepository {
    private let client: any ReciclarAPIClient
    private let store: any StatsPersisting
    private let policy: SyncPolicy
    private var cache: CachedCatalogStatistics?
    public private(set) var status: RepositoryStatus = .idle
    public private(set) var lastRefreshError: String?

    public init(
        client: any ReciclarAPIClient,
        store: any StatsPersisting,
        policy: SyncPolicy = .approved
    ) {
        self.client = client
        self.store = store
        self.policy = policy
    }

    public func current() -> CatalogStatistics? { cache?.statistics }

    public func loadCache() async {
        do {
            cache = try await store.load()
        } catch {
            lastRefreshError = "Não foi possível ler a cache local."
            cache = nil
        }
    }

    public func refreshIfNeeded(now: Date, force: Bool = false) async {
        if !force, let fetchedAt = cache?.fetchedAt, now.timeIntervalSince(fetchedAt) < policy.interval {
            return
        }
        await refresh(now: now)
    }

    public func refresh(now: Date) async {
        status = cache == nil ? .loading : .refreshing
        lastRefreshError = nil
        do {
            let statistics = try await client.fetchStats()
            let next = CachedCatalogStatistics(statistics: statistics, fetchedAt: now)
            try await store.save(next)
            cache = next
            status = .idle
        } catch {
            if cache == nil, let message = (error as? ReciclarAPIError)?.userMessage, !message.isEmpty {
                lastRefreshError = message
            } else {
                lastRefreshError = "Não foi possível atualizar as estatísticas. A informação guardada continua disponível."
            }
            status = .failed(lastRefreshError!)
        }
    }
}
