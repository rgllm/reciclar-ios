import Foundation

/// Readings and provenance used only while capturing App Store screenshots.
/// Production responses are left unchanged. The app installs `StoreCaptureAPIClient`
/// only when it is launched with `-StoreScreenshots`.
public enum StoreCaptureFixtures {
    /// Blank operator label. Build 1.1.0 hides the provenance line when the label is empty.
    public static let hiddenProvenance = DataProvenance(label: "")

    /// Inside the 24-hour window, and never in the future.
    public static let readingAge: TimeInterval = 60 * 60

    public static func present(_ location: Ecoponto, now: Date) -> Ecoponto {
        var copy = location
        copy.provenance = hiddenProvenance
        let recordedAt = now.addingTimeInterval(-readingAge)
        copy.containers = location.containers.enumerated().map { index, container in
            var container = container
            if FillReadingPolicy.evidence(from: container.fillReading, at: now) == .none {
                container.fillReading = FillReading(
                    percentFull: percent(locationID: location.id, containerIndex: index),
                    recordedAt: recordedAt
                )
            }
            return container
        }
        return copy
    }

    /// Most locations stay under 90% so the map can show "Com espaço".
    /// Every location whose hash falls on a fifth stays full, so the space filter
    /// has something to hide. Every value is a real reading, never the no-reading state.
    /// Containers at one location stay on the same side of 90%.
    public static func percent(locationID: String, containerIndex: Int) -> Int {
        let hash = stableHash(locationID)
        let offset = (hash / 5) + containerIndex * 3
        if hash % 5 == 0 {
            return 92 + (offset % 7)
        }
        return 18 + (offset % 64)
    }

    private static func stableHash(_ value: String) -> Int {
        var hash = 5381
        for byte in value.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return hash & 0x7fff_ffff
    }
}

/// Pass-through client that applies `StoreCaptureFixtures` to location payloads.
/// Statistics, community events and report submission stay on the upstream client.
public struct StoreCaptureAPIClient: ReciclarAPIClient {
    private let upstream: any ReciclarAPIClient
    private let clock: @Sendable () -> Date

    public init(upstream: any ReciclarAPIClient, clock: @escaping @Sendable () -> Date) {
        self.upstream = upstream
        self.clock = clock
    }

    public func fetchStats() async throws -> CatalogStatistics {
        try await upstream.fetchStats()
    }

    public func fetchArea(bounds: GeographicBounds, cursor: String?) async throws -> AreaPage {
        var page = try await upstream.fetchArea(bounds: bounds, cursor: cursor)
        page.page.locations = present(page.page.locations)
        return page
    }

    public func fetchTile(_ tile: SlippyTileCoordinate, cursor: String?) async throws -> TilePage {
        var page = try await upstream.fetchTile(tile, cursor: cursor)
        page.page.locations = present(page.page.locations)
        return page
    }

    public func fetchCommunityEvents(bounds: GeographicBounds) async throws -> CommunityEventsPage {
        try await upstream.fetchCommunityEvents(bounds: bounds)
    }

    public func fetchLocations(ids: [String]) async throws -> LocationIDBatch {
        var batch = try await upstream.fetchLocations(ids: ids)
        batch.locations = present(batch.locations)
        return batch
    }

    public func fetchLocation(id: String) async throws -> LocationDetailResponse {
        var detail = try await upstream.fetchLocation(id: id)
        detail.location = StoreCaptureFixtures.present(detail.location, now: clock())
        return detail
    }

    public func submitReport(_ request: IssueSubmissionRequest) async throws -> CommunityEvent {
        try await upstream.submitReport(request)
    }

    public func submitResolution(_ request: IssueResolutionRequest) async throws -> CommunityEvent {
        try await upstream.submitResolution(request)
    }

    private func present(_ locations: [Ecoponto]) -> [Ecoponto] {
        let now = clock()
        return locations.map { StoreCaptureFixtures.present($0, now: now) }
    }
}
