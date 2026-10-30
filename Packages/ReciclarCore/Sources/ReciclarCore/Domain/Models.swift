import Foundation

public struct Coordinate: Hashable, Sendable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        latitude.isFinite
            && longitude.isFinite
            && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
    }

    public var displayString: String {
        "\(format(latitude)), \(format(longitude))"
    }

    private func format(_ value: Double) -> String {
        String(format: "%.5f", locale: Locale(identifier: "pt_PT"), value)
    }
}

public struct FillReading: Hashable, Sendable, Codable {
    /// Validated fullness percentage in 0...100. Malformed readings never become 0.
    public var percentFull: Int
    public var recordedAt: Date

    public init(percentFull: Int, recordedAt: Date) {
        self.percentFull = percentFull
        self.recordedAt = recordedAt
    }
}

public struct Container: Identifiable, Hashable, Sendable, Codable {
    /// Container id kept as a string. Uniqueness across sensor replacement is unconfirmed.
    public var id: String
    public var category: WasteCategory
    public var colorToken: String?
    public var volumeLitres: Int?
    public var typeDescription: String?
    public var code: String?
    public var fillReading: FillReading?
    public var lastCollectionAt: Date?
    public var lastWashingAt: Date?

    public init(
        id: String,
        category: WasteCategory,
        colorToken: String? = nil,
        volumeLitres: Int? = nil,
        typeDescription: String? = nil,
        code: String? = nil,
        fillReading: FillReading? = nil,
        lastCollectionAt: Date? = nil,
        lastWashingAt: Date? = nil
    ) {
        self.id = id
        self.category = category
        self.colorToken = colorToken
        self.volumeLitres = volumeLitres
        self.typeDescription = typeDescription
        self.code = code
        self.fillReading = fillReading
        self.lastCollectionAt = lastCollectionAt
        self.lastWashingAt = lastWashingAt
    }
}

public struct DataProvenance: Hashable, Sendable, Codable {
    public var label: String

    public init(label: String) {
        self.label = label
    }

    public static let developmentFixture = DataProvenance(label: "Fixture de desenvolvimento")

    /// Operator name when the label uses `prefix / operator`. A blank label is hidden.
    public var userFacingLabel: String? {
        Self.userFacingLabel(from: label)
    }

    public static func userFacingLabel(from raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let separator = " / "
        guard let range = value.range(of: separator, options: .backwards) else { return value }
        let operatorName = value[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return operatorName.isEmpty ? nil : operatorName
    }
}

public struct Ecoponto: Identifiable, Hashable, Sendable, Codable {
    /// Location id kept as a string. Global uniqueness is unconfirmed.
    public var id: String
    public var concessionaireID: String?
    public var coordinate: Coordinate
    public var district: String?
    public var municipality: String?
    public var parish: String?
    public var locality: String?
    public var address: String?
    public var locationDescription: String?
    public var containers: [Container]
    public var provenance: DataProvenance

    public init(
        id: String,
        concessionaireID: String? = nil,
        coordinate: Coordinate,
        district: String? = nil,
        municipality: String? = nil,
        parish: String? = nil,
        locality: String? = nil,
        address: String? = nil,
        locationDescription: String? = nil,
        containers: [Container],
        provenance: DataProvenance
    ) {
        self.id = id
        self.concessionaireID = concessionaireID
        self.coordinate = coordinate
        self.district = district
        self.municipality = municipality
        self.parish = parish
        self.locality = locality
        self.address = address
        self.locationDescription = locationDescription
        self.containers = containers
        self.provenance = provenance
    }

    public var acceptedCategoryIDs: Set<WasteCategory.ID> {
        Set(containers.map(\.category.id))
    }

    public var acceptedCategories: [WasteCategory] {
        var seen = Set<WasteCategory.ID>()
        var result: [WasteCategory] = []
        for container in containers where seen.insert(container.category.id).inserted {
            result.append(container.category)
        }
        return result
    }

    /// User-facing title. Never uses the raw `localgroups` operational string.
    public var displayName: String {
        if let locality { return locality }
        if let parish { return parish }
        if let municipality { return municipality }
        return coordinate.displayString
    }

    public var placeLine: String? {
        if let address { return address }
        let parts = [parish, municipality, district].compactMap { $0 }
        if parts.isEmpty { return nil }
        return parts.joined(separator: ", ")
    }
}

public enum CommunityIssueKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case rubbishOutsideContainers
    case vandalised

    public var id: String { rawValue }

    public var portugueseLabel: String {
        switch self {
        case .rubbishOutsideContainers: "Lixo fora dos contentores"
        case .vandalised: "Vandalizado"
        }
    }

    public var wireValue: String {
        switch self {
        case .rubbishOutsideContainers: "litter_outside_containers"
        case .vandalised: "vandalized"
        }
    }

    public init?(wireValue: String) {
        switch wireValue {
        case "litter_outside_containers", "rubbishOutsideContainers":
            self = .rubbishOutsideContainers
        case "vandalized", "vandalised":
            self = .vandalised
        default:
            return nil
        }
    }
}

public enum CommunityEventKind: String, Codable, Sendable {
    case report
    case resolution
}

public struct CommunityEvent: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var ecopontoID: String
    public var issue: CommunityIssueKind
    public var kind: CommunityEventKind
    public var serverTimestamp: Date

    public init(
        id: String,
        ecopontoID: String,
        issue: CommunityIssueKind,
        kind: CommunityEventKind,
        serverTimestamp: Date
    ) {
        self.id = id
        self.ecopontoID = ecopontoID
        self.issue = issue
        self.kind = kind
        self.serverTimestamp = serverTimestamp
    }
}

public struct VisibleCommunityIssue: Hashable, Sendable, Identifiable {
    public var kind: CommunityIssueKind
    public var reportedAt: Date

    public var id: CommunityIssueKind { kind }
}

public struct LocationSnapshot: Hashable, Sendable, Codable {
    public var cachedAreas: [CachedArea] = []
    public var locations: [Ecoponto]
    public var communityEvents: [CommunityEvent]
    public var lastSuccessfulSync: Date?
    public var isFixtureData: Bool
    /// Legacy sync cursor kept so older caches still decode. Area refresh clears it.
    public var syncToken: String?
    public var removedLocationIDs: Set<String>
    public var coverageNote: String?
    /// Viewports whose community events were fetched. Separate from tile coverage.
    public var communityEventAreas: [CachedArea] = []
    /// Retired location ids retargeted to the public id that shares their coordinate.
    /// Kept until favourites adopt the new ids, including across a relaunch.
    public var identityRenames: [String: String] = [:]

    public init(
        locations: [Ecoponto] = [],
        communityEvents: [CommunityEvent] = [],
        lastSuccessfulSync: Date? = nil,
        isFixtureData: Bool = false,
        syncToken: String? = nil,
        removedLocationIDs: Set<String> = [],
        coverageNote: String? = nil,
        communityEventAreas: [CachedArea] = [],
        identityRenames: [String: String] = [:]
    ) {
        self.locations = locations
        self.communityEvents = communityEvents
        self.lastSuccessfulSync = lastSuccessfulSync
        self.isFixtureData = isFixtureData
        self.syncToken = syncToken
        self.removedLocationIDs = removedLocationIDs
        self.coverageNote = coverageNote
        self.communityEventAreas = communityEventAreas
        self.identityRenames = identityRenames
    }

    public var hasCompletedSync: Bool { syncToken != nil }

    public func location(id: String) -> Ecoponto? {
        locations.first { $0.id == id }
    }

    enum CodingKeys: String, CodingKey {
        case cachedAreas
        case locations
        case communityEvents
        case lastSuccessfulSync
        case isFixtureData
        case syncToken
        case removedLocationIDs
        case coverageNote
        case communityEventAreas
        case identityRenames
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cachedAreas = try container.decodeIfPresent([CachedArea].self, forKey: .cachedAreas) ?? []
        locations = try container.decode([Ecoponto].self, forKey: .locations)
        communityEvents = try container.decodeIfPresent([CommunityEvent].self, forKey: .communityEvents) ?? []
        lastSuccessfulSync = try container.decodeIfPresent(Date.self, forKey: .lastSuccessfulSync)
        isFixtureData = try container.decodeIfPresent(Bool.self, forKey: .isFixtureData) ?? false
        syncToken = try container.decodeIfPresent(String.self, forKey: .syncToken)
        removedLocationIDs = try container.decodeIfPresent(Set<String>.self, forKey: .removedLocationIDs) ?? []
        coverageNote = try container.decodeIfPresent(String.self, forKey: .coverageNote)
        communityEventAreas = try container.decodeIfPresent([CachedArea].self, forKey: .communityEventAreas) ?? []
        identityRenames = try container.decodeIfPresent([String: String].self, forKey: .identityRenames) ?? [:]
    }
}

public struct LocationSyncPage: Sendable {
    public var locations: [Ecoponto]
    public var communityEvents: [CommunityEvent]
    public var removedIDs: [String]
    public var isCompleteReplacement: Bool
    public var isFixtureData: Bool
    public var hasMore: Bool
    public var nextCursor: String?
    public var syncToken: String?
    public var asOf: Date?
    public var coverageNote: String?

    public init(
        locations: [Ecoponto],
        communityEvents: [CommunityEvent],
        removedIDs: [String] = [],
        isCompleteReplacement: Bool,
        isFixtureData: Bool,
        hasMore: Bool = false,
        nextCursor: String? = nil,
        syncToken: String? = nil,
        asOf: Date? = nil,
        coverageNote: String? = nil
    ) {
        self.locations = locations
        self.communityEvents = communityEvents
        self.removedIDs = removedIDs
        self.isCompleteReplacement = isCompleteReplacement
        self.isFixtureData = isFixtureData
        self.hasMore = hasMore
        self.nextCursor = nextCursor
        self.syncToken = syncToken
        self.asOf = asOf
        self.coverageNote = coverageNote
    }
}

public struct LocationDetailResponse: Sendable {
    public var location: Ecoponto
    public var communityEvents: [CommunityEvent]

    public init(location: Ecoponto, communityEvents: [CommunityEvent]) {
        self.location = location
        self.communityEvents = communityEvents
    }
}

public struct CatalogStatistics: Hashable, Sendable, Codable {
    public var asOf: Date?
    public var syncToken: String?
    public var isFixtureData: Bool
    public var coverageNote: String
    public var fillNote: String?
    public var fillEvaluatedAt: Date?
    public var geography: StatsGeography
    public var density: StatsDensity
    public var locations: LocationStats
    public var containers: ContainerStats?
    public var districts: [DistrictStats]
    public var community: CommunityStats?

    public init(
        asOf: Date? = nil,
        syncToken: String? = nil,
        isFixtureData: Bool,
        coverageNote: String,
        fillNote: String? = nil,
        fillEvaluatedAt: Date? = nil,
        geography: StatsGeography,
        density: StatsDensity,
        locations: LocationStats,
        containers: ContainerStats? = nil,
        districts: [DistrictStats] = [],
        community: CommunityStats? = nil
    ) {
        self.asOf = asOf
        self.syncToken = syncToken
        self.isFixtureData = isFixtureData
        self.coverageNote = coverageNote
        self.fillNote = fillNote
        self.fillEvaluatedAt = fillEvaluatedAt
        self.geography = geography
        self.density = density
        self.locations = locations
        self.containers = containers
        self.districts = districts
        self.community = community
    }

    public var hasFillStats: Bool { containers != nil }
}

public struct StatsGeography: Hashable, Sendable, Codable {
    public var country: String
    public var areaKm2: Double
    public var roadKm: Double

    public init(country: String = "PT", areaKm2: Double, roadKm: Double) {
        self.country = country
        self.areaKm2 = areaKm2
        self.roadKm = roadKm
    }
}

public struct StatsDensity: Hashable, Sendable, Codable {
    public var locationsPer100RoadKm: Double
    public var locationsPerKm2: Double
    public var withSpacePer100RoadKm: Double?
    public var withSpacePerKm2: Double?

    public init(
        locationsPer100RoadKm: Double,
        locationsPerKm2: Double,
        withSpacePer100RoadKm: Double? = nil,
        withSpacePerKm2: Double? = nil
    ) {
        self.locationsPer100RoadKm = locationsPer100RoadKm
        self.locationsPerKm2 = locationsPerKm2
        self.withSpacePer100RoadKm = withSpacePer100RoadKm
        self.withSpacePerKm2 = withSpacePerKm2
    }
}

public struct LocationStats: Hashable, Sendable, Codable {
    public var total: Int
    public var districts: Int
    public var municipalities: Int
    public var operators: Int
    public var withSpaceAvailable: Int?
    public var withUsableReading: Int?
    public var withSpacePercent: Int?

    public init(
        total: Int,
        districts: Int,
        municipalities: Int,
        operators: Int,
        withSpaceAvailable: Int? = nil,
        withUsableReading: Int? = nil,
        withSpacePercent: Int? = nil
    ) {
        self.total = total
        self.districts = districts
        self.municipalities = municipalities
        self.operators = operators
        self.withSpaceAvailable = withSpaceAvailable
        self.withUsableReading = withUsableReading
        self.withSpacePercent = withSpacePercent
    }
}

public struct ContainerStats: Hashable, Sendable, Codable {
    public var total: Int
    public var withUsableReading: Int
    public var withUsableReadingPercent: Int
    public var withSpaceAvailable: Int
    public var byStream: [StreamCount]

    public init(
        total: Int,
        withUsableReading: Int,
        withUsableReadingPercent: Int,
        withSpaceAvailable: Int,
        byStream: [StreamCount]
    ) {
        self.total = total
        self.withUsableReading = withUsableReading
        self.withUsableReadingPercent = withUsableReadingPercent
        self.withSpaceAvailable = withSpaceAvailable
        self.byStream = byStream
    }
}

public struct StreamCount: Hashable, Sendable, Codable, Identifiable {
    public var id: String
    public var name: String
    public var count: Int

    public init(id: String, name: String, count: Int) {
        self.id = id
        self.name = name
        self.count = count
    }
}

public struct DistrictStats: Hashable, Sendable, Codable, Identifiable {
    public var name: String
    public var locationCount: Int
    public var containerCount: Int

    public var id: String { name }

    public init(name: String, locationCount: Int, containerCount: Int = 0) {
        self.name = name
        self.locationCount = locationCount
        self.containerCount = containerCount
    }
}

public struct CommunityStats: Hashable, Sendable, Codable {
    public var locationsWithVisibleIssues: Int
    public var litterOutsideContainers: Int
    public var vandalized: Int

    public init(locationsWithVisibleIssues: Int, litterOutsideContainers: Int, vandalized: Int) {
        self.locationsWithVisibleIssues = locationsWithVisibleIssues
        self.litterOutsideContainers = litterOutsideContainers
        self.vandalized = vandalized
    }

    public var hasVisibleIssues: Bool {
        locationsWithVisibleIssues > 0 || litterOutsideContainers > 0 || vandalized > 0
    }
}

public struct CachedCatalogStatistics: Hashable, Sendable, Codable {
    public var statistics: CatalogStatistics
    public var fetchedAt: Date

    public init(statistics: CatalogStatistics, fetchedAt: Date) {
        self.statistics = statistics
        self.fetchedAt = fetchedAt
    }
}

public struct LocationFix: Hashable, Sendable {
    public var coordinate: Coordinate
    public var horizontalAccuracy: Double
    public var timestamp: Date

    public init(coordinate: Coordinate, horizontalAccuracy: Double, timestamp: Date) {
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
    }
}

public struct IssueSubmissionRequest: Sendable {
    public var ecopontoID: String
    public var issue: CommunityIssueKind

    public init(ecopontoID: String, issue: CommunityIssueKind) {
        self.ecopontoID = ecopontoID
        self.issue = issue
    }
}

public struct IssueResolutionRequest: Sendable {
    public var ecopontoID: String
    public var issue: CommunityIssueKind

    public init(ecopontoID: String, issue: CommunityIssueKind) {
        self.ecopontoID = ecopontoID
        self.issue = issue
    }
}

public enum ReciclarAPIError: Error, Sendable, Equatable {
    case unavailable
    case invalidResponse
    case submissionRejected
    case invalidSyncToken
    case proximity(String)
    case notFound
    case gone
    case rateLimited(String, retryAfter: TimeInterval?)
    /// 503, including `area_unavailable`. Distinct from a generic transport failure and from 429.
    case serviceUnavailable(String, retryAfter: TimeInterval?)
    case server(status: Int, code: String, message: String)

    public var retryAfter: TimeInterval? {
        switch self {
        case .rateLimited(_, let retryAfter), .serviceUnavailable(_, let retryAfter):
            retryAfter
        default:
            nil
        }
    }

    public var userMessage: String? {
        switch self {
        case .proximity(let message), .rateLimited(let message, _), .serviceUnavailable(let message, _):
            message
        case .server(_, _, let message):
            message
        case .gone:
            "Este ecoponto já não consta da fonte."
        case .notFound:
            "Este ecoponto não está disponível."
        case .unavailable, .invalidResponse, .submissionRejected, .invalidSyncToken:
            nil
        }
    }
}

public struct SyncPolicy: Sendable, Equatable {
    public var interval: TimeInterval
    public var maxAttempts: Int
    public var baseDelayNanoseconds: UInt64

    public init(
        interval: TimeInterval = 15 * 60,
        maxAttempts: Int = 3,
        baseDelayNanoseconds: UInt64 = 400_000_000
    ) {
        self.interval = interval
        self.maxAttempts = maxAttempts
        self.baseDelayNanoseconds = baseDelayNanoseconds
    }

    public static let approved = SyncPolicy()
}

public enum RepositoryStatus: Equatable, Sendable {
    case idle
    case loading
    case refreshing
    case failed(String)
}

public struct FavouriteRecord: Hashable, Sendable, Codable {
    public var ecopontoID: String
    public var savedAt: Date

    public init(ecopontoID: String, savedAt: Date) {
        self.ecopontoID = ecopontoID
        self.savedAt = savedAt
    }
}
