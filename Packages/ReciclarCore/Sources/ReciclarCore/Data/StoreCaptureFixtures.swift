import Foundation

/// Readings and provenance used only while capturing App Store screenshots.
/// Production responses are left unchanged. The app installs `StoreCaptureAPIClient`
/// only when it is launched with `-StoreScreenshots`.
public enum StoreCaptureFixtures {
    /// Real points near Barcelos city centre (41.5388, -8.6151), from the public catalogue.
    /// The live tile is many pages and the capture cannot wait for all of them.
    public static func locations(at now: Date) -> [Ecoponto] {
        let spots: [(id: String, latitude: Double, longitude: Double, address: String)] = [
            ("01", 41.53947, -8.61533, "Rua Dr. Aníbal Araújo, Barcelos"),
            ("02", 41.53855, -8.61406, "Rua Selles Paes, Barcelos"),
            ("03", 41.53819, -8.61385, "Bomba Gasolina, Barcelos"),
            ("04", 41.54007, -8.61540, "Café Estudante, Barcelos"),
            ("05", 41.53745, -8.61460, "Travessa João Duarte, Barcelos"),
            ("06", 41.53762, -8.61637, "Escola Gonçalo Nunes, Barcelos"),
            ("07", 41.54055, -8.61488, "CTT, Barcelos"),
            ("08", 41.54017, -8.61713, "Pizzaria, Barcelos"),
            ("09", 41.54084, -8.61624, "Rua Tomé de Sousa, Barcelos"),
            ("10", 41.53712, -8.61285, "Rua D. Afonso, Barcelos"),
            ("11", 41.54123, -8.61485, "Rua de Santa Clara, Barcelos"),
            ("12", 41.53827, -8.61197, "Rotunda da Cabra, Barcelos"),
            ("13", 41.54131, -8.61386, "Cozinha Nova, Barcelos"),
            ("14", 41.54031, -8.61211, "Hyundai, Barcelos"),
            ("15", 41.54149, -8.61679, "Peixaria Novimar, Barcelos"),
            ("16", 41.53680, -8.61840, "Arcozelo, Barcelos"),
        ]
        return spots.map { spot in
            let id = "capture-barcelos-\(spot.id)"
            let recordedAt = now.addingTimeInterval(-readingAge)
            let collectedAt = now.addingTimeInterval(-36 * 60 * 60)
            let containers = [
                ("glass", WasteCategory.sampleGlass, "Verde"),
                ("packaging", WasteCategory.samplePackaging, "Amarelo"),
                ("paper", WasteCategory.samplePaper, "Azul"),
            ].enumerated().map { index, item in
                Container(
                    id: "\(id)-\(item.0)",
                    category: item.1,
                    colorToken: item.2,
                    volumeLitres: 2500,
                    fillReading: FillReading(
                        percentFull: percent(locationID: id, containerIndex: index),
                        recordedAt: recordedAt
                    ),
                    lastCollectionAt: collectedAt
                )
            }
            return Ecoponto(
                id: id,
                coordinate: Coordinate(latitude: spot.latitude, longitude: spot.longitude),
                district: "Braga",
                municipality: "Barcelos",
                parish: "Arcozelo",
                locality: "Barcelos",
                address: spot.address,
                containers: containers,
                provenance: hiddenProvenance
            )
        }
    }

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
        let now = clock()
        let fixtures = StoreCaptureFixtures.locations(at: now).filter { tile.bounds.contains($0.coordinate) }
        let page = LocationSyncPage(
            locations: cursor == nil ? fixtures : [],
            communityEvents: [],
            isCompleteReplacement: false,
            isFixtureData: false,
            hasMore: false,
            syncToken: "capture"
        )
        return TilePage(tile: tile, bounds: tile.bounds, page: page)
    }

    public func fetchCommunityEvents(bounds: GeographicBounds) async throws -> CommunityEventsPage {
        _ = bounds
        return CommunityEventsPage(asOf: clock(), events: [])
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
