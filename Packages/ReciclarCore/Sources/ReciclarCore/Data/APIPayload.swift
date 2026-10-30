import Foundation

enum APIJSONCoding {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeDate)
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601String(from: date, fractional: true))
        }
        return encoder
    }

    static func decodeDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let date = parseISO8601(raw) {
            return date
        }
        if !raw.contains("+"), !raw.uppercased().hasSuffix("Z"), let date = parseISO8601(raw + "Z") {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date \(raw)")
    }
}

private let iso8601Lock = NSLock()
private nonisolated(unsafe) let fractionalISO8601: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()
private nonisolated(unsafe) let standardISO8601: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

private func parseISO8601(_ raw: String) -> Date? {
    iso8601Lock.lock()
    defer { iso8601Lock.unlock() }
    return fractionalISO8601.date(from: raw) ?? standardISO8601.date(from: raw)
}

private func iso8601String(from date: Date, fractional: Bool) -> String {
    iso8601Lock.lock()
    defer { iso8601Lock.unlock() }
    return fractional ? fractionalISO8601.string(from: date) : standardISO8601.string(from: date)
}

struct APIErrorDTO: Decodable, Sendable {
    var error: String
    var message: String
}

struct APIWasteTypesDTO: Decodable, Sendable {
    var waste_types: [APIWasteTypeDTO]
}

struct APIWasteTypeDTO: Decodable, Sendable {
    var id: FlexibleIdentifier
    var name: String
}

struct APICatalogStatsDTO: Decodable, Sendable {
    var as_of: Date?
    var sync_token: String?
    var is_fixture_data: Bool?
    var coverage_note: String
    var fill_note: String?
    var fill_evaluated_at: Date?
    var geography: APIStatsGeographyDTO
    var density: APIStatsDensityDTO
    var locations: APILocationStatsDTO
    var containers: APIContainerStatsDTO?
    var districts: [APIDistrictStatsDTO]
    var community: APICommunityStatsDTO?
}

struct APIStatsGeographyDTO: Decodable, Sendable {
    var country: String?
    var area_km2: Double
    var road_km: Double
}

struct APIStatsDensityDTO: Decodable, Sendable {
    var locations_per_100_road_km: Double
    var locations_per_km2: Double
    var with_space_per_100_road_km: Double?
    var with_space_per_km2: Double?
}

struct APILocationStatsDTO: Decodable, Sendable {
    var total: Int
    var districts: Int
    var municipalities: Int
    var operators: Int
    var with_space_available: Int?
    var with_usable_reading: Int?
    var with_space_percent: Int?
}

struct APIContainerStatsDTO: Decodable, Sendable {
    var total: Int
    var with_usable_reading: Int
    var with_usable_reading_percent: Int
    var with_space_available: Int
    var by_stream: [APIStreamCountDTO]
}

struct APIStreamCountDTO: Decodable, Sendable {
    var id: String
    var name: String
    var count: Int
}

struct APIDistrictStatsDTO: Decodable, Sendable {
    var name: String
    var location_count: Int
    var container_count: Int?
}

struct APICommunityStatsDTO: Decodable, Sendable {
    var locations_with_visible_issues: Int
    var visible_issues: APIVisibleIssueCountsDTO?
}

struct APIVisibleIssueCountsDTO: Decodable, Sendable {
    var litter_outside_containers: Int?
    var vandalized: Int?
}

struct APIAreaScopeDTO: Decodable, Sendable {
    var kind: String
    var bbox: [Double]
}

struct APILocationsPageDTO: Decodable, Sendable {
    var scope: APIAreaScopeDTO?
    var as_of: Date?
    var sync_token: String?
    var is_complete_replacement: Bool
    var is_fixture_data: Bool
    var has_more: Bool
    var next_cursor: String?
    var locations: [APILocationDTO]
    var removed_ids: [FlexibleIdentifier]
    var community_events: [APICommunityEventDTO]
}

struct APILocationDetailDTO: Decodable, Sendable {
    var location: APILocationDTO
    var community_events: [APICommunityEventDTO]
}

struct APILocationDTO: Decodable, Sendable {
    var id: FlexibleIdentifier
    var concessionaire_id: FlexibleIdentifier?
    var latitude: Double
    var longitude: Double
    var district: String?
    var municipality: String?
    var parish: String?
    var locality: String?
    var address: String?
    var location_description: String?
    var provenance: APIProvenanceDTO
    var updated_at: Date?
    var containers: [APIContainerDTO]
    var active_issues: [APIActiveIssueDTO]?
}

struct APIProvenanceDTO: Decodable, Sendable {
    var label: String
}

struct APIContainerDTO: Decodable, Sendable {
    var id: FlexibleIdentifier
    var waste_type_id: FlexibleIdentifier
    var waste_name: String
    var color_token: String?
    var volume_litres: FlexibleNumber?
    var type_description: String?
    var code: FlexibleIdentifier?
    var fill: APIFillDTO?
    var last_collection_at: Date?
    var last_washing_at: Date?
}

struct APIFillDTO: Decodable, Sendable {
    var percent_full: FlexibleNumber
    var recorded_at: Date
    var space_available: Bool?
}

struct APICommunityEventDTO: Decodable, Sendable {
    var id: String
    var ecoponto_id: FlexibleIdentifier?
    var location_id: FlexibleIdentifier?
    var issue: String
    var kind: String
    var server_timestamp: Date

    var placeID: String? {
        let value = location_id?.rawValue ?? ecoponto_id?.rawValue
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

struct APITileIndexDTO: Decodable, Sendable {
    var z: Int
    var x: Int
    var y: Int
}

struct APITileResponseDTO: Decodable, Sendable {
    var sync_token: String?
    var tile: APITileIndexDTO
    var bbox: [Double]
    var locations: [APILocationDTO]
    var next_cursor: String?
    var has_more: Bool
}

struct APICommunityEventsDTO: Decodable, Sendable {
    var as_of: Date?
    var events: [APICommunityEventDTO]
}

struct APILocationIDBatchDTO: Decodable, Sendable {
    var locations: [APILocationDTO]
    var missing: [FlexibleIdentifier]
}

struct APIActiveIssueDTO: Decodable, Sendable {
    var issue: String
    var reported_at: Date
}

struct FlexibleNumber: Decodable, Sendable {
    var intValue: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            intValue = nil
            return
        }
        if let int = try? container.decode(Int.self) {
            intValue = int
            return
        }
        if let double = try? container.decode(Double.self), double.isFinite {
            intValue = Int(double.rounded())
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a number")
    }
}

enum APILocationMapper {
    static func page(from dto: APILocationsPageDTO, coverageNote: String? = nil) -> LocationSyncPage {
        LocationSyncPage(
            locations: dto.locations.compactMap(location(from:)),
            communityEvents: dto.community_events.compactMap(event(from:)),
            removedIDs: dto.removed_ids.map(\.rawValue),
            isCompleteReplacement: dto.is_complete_replacement,
            isFixtureData: dto.is_fixture_data,
            hasMore: dto.has_more,
            nextCursor: dto.next_cursor,
            syncToken: dto.sync_token,
            asOf: dto.as_of,
            coverageNote: coverageNote
        )
    }

    static func detail(from dto: APILocationDetailDTO) throws -> LocationDetailResponse {
        guard let location = location(from: dto.location) else {
            throw ReciclarAPIError.invalidResponse
        }
        return LocationDetailResponse(
            location: location,
            communityEvents: dto.community_events.compactMap(event(from:))
        )
    }

    static func statistics(from dto: APICatalogStatsDTO) -> CatalogStatistics {
        CatalogStatistics(
            asOf: dto.as_of,
            syncToken: dto.sync_token,
            isFixtureData: dto.is_fixture_data ?? false,
            coverageNote: dto.coverage_note,
            fillNote: dto.fill_note,
            fillEvaluatedAt: dto.fill_evaluated_at,
            geography: StatsGeography(
                country: dto.geography.country ?? "PT",
                areaKm2: dto.geography.area_km2,
                roadKm: dto.geography.road_km
            ),
            density: StatsDensity(
                locationsPer100RoadKm: dto.density.locations_per_100_road_km,
                locationsPerKm2: dto.density.locations_per_km2,
                withSpacePer100RoadKm: dto.density.with_space_per_100_road_km,
                withSpacePerKm2: dto.density.with_space_per_km2
            ),
            locations: LocationStats(
                total: dto.locations.total,
                districts: dto.locations.districts,
                municipalities: dto.locations.municipalities,
                operators: dto.locations.operators,
                withSpaceAvailable: dto.locations.with_space_available,
                withUsableReading: dto.locations.with_usable_reading,
                withSpacePercent: dto.locations.with_space_percent
            ),
            containers: dto.containers.map { containers in
                ContainerStats(
                    total: containers.total,
                    withUsableReading: containers.with_usable_reading,
                    withUsableReadingPercent: containers.with_usable_reading_percent,
                    withSpaceAvailable: containers.with_space_available,
                    byStream: containers.by_stream.map {
                        StreamCount(id: $0.id, name: $0.name, count: $0.count)
                    }
                )
            },
            districts: dto.districts.map {
                DistrictStats(name: $0.name, locationCount: $0.location_count, containerCount: $0.container_count ?? 0)
            },
            community: dto.community.map { community in
                CommunityStats(
                    locationsWithVisibleIssues: community.locations_with_visible_issues,
                    litterOutsideContainers: community.visible_issues?.litter_outside_containers ?? 0,
                    vandalized: community.visible_issues?.vandalized ?? 0
                )
            }
        )
    }

    static func event(from dto: APICommunityEventDTO) -> CommunityEvent? {
        guard let issue = CommunityIssueKind(wireValue: dto.issue) else { return nil }
        let kind: CommunityEventKind
        switch dto.kind {
        case "report": kind = .report
        case "resolution": kind = .resolution
        default: return nil
        }
        guard let placeID = dto.placeID else { return nil }
        return CommunityEvent(
            id: dto.id,
            ecopontoID: placeID,
            issue: issue,
            kind: kind,
            serverTimestamp: dto.server_timestamp
        )
    }

    static func tilePage(from dto: APITileResponseDTO) -> TilePage? {
        guard dto.bbox.count == 4,
              let syncToken = dto.sync_token, !syncToken.isEmpty else { return nil }
        let bounds = GeographicBounds(
            minLatitude: dto.bbox[1],
            maxLatitude: dto.bbox[3],
            minLongitude: dto.bbox[0],
            maxLongitude: dto.bbox[2]
        )
        guard bounds.isValid else { return nil }
        let locations = dto.locations.compactMap(location(from:))
        guard locations.count == dto.locations.count else { return nil }
        let page = LocationSyncPage(
            locations: locations,
            communityEvents: [],
            isCompleteReplacement: false,
            isFixtureData: false,
            hasMore: dto.has_more,
            nextCursor: dto.next_cursor,
            syncToken: syncToken
        )
        return TilePage(
            tile: SlippyTileCoordinate(z: dto.tile.z, x: dto.tile.x, y: dto.tile.y),
            bounds: bounds,
            page: page
        )
    }

    static func events(from dto: APICommunityEventsDTO) -> CommunityEventsPage {
        CommunityEventsPage(asOf: dto.as_of, events: dto.events.compactMap(event(from:)))
    }

    static func idBatch(from dto: APILocationIDBatchDTO) -> LocationIDBatch? {
        let locations = dto.locations.compactMap(location(from:))
        guard locations.count == dto.locations.count else { return nil }
        return LocationIDBatch(locations: locations, missing: dto.missing.map(\.rawValue))
    }

    static func location(from dto: APILocationDTO) -> Ecoponto? {
        let coordinate = Coordinate(latitude: dto.latitude, longitude: dto.longitude)
        guard coordinate.isValid else { return nil }
        let provenanceLabel = DataProvenance.userFacingLabel(from: dto.provenance.label) ?? ""
        return Ecoponto(
            id: dto.id.rawValue,
            concessionaireID: UpstreamParsing.absentIfBlank(dto.concessionaire_id?.rawValue),
            coordinate: coordinate,
            district: placeholderToNil(dto.district),
            municipality: placeholderToNil(dto.municipality),
            parish: placeholderToNil(dto.parish),
            locality: placeholderToNil(dto.locality),
            address: placeholderToNil(dto.address),
            locationDescription: placeholderToNil(dto.location_description),
            containers: dto.containers.map(container(from:)),
            provenance: DataProvenance(label: provenanceLabel)
        )
    }

    static func container(from dto: APIContainerDTO) -> Container {
        let name = UpstreamParsing.absentIfBlank(dto.waste_name) ?? "Categoria \(dto.waste_type_id.rawValue)"
        let fill: FillReading?
        if let raw = dto.fill, let percent = raw.percent_full.intValue, (0...100).contains(percent) {
            fill = FillReading(percentFull: percent, recordedAt: raw.recorded_at)
        } else {
            fill = nil
        }
        return Container(
            id: dto.id.rawValue,
            category: WasteCategory(id: WasteCategory.ID(dto.waste_type_id.rawValue), name: name),
            colorToken: UpstreamParsing.absentIfBlank(dto.color_token),
            volumeLitres: dto.volume_litres?.intValue.flatMap { $0 > 0 ? $0 : nil },
            typeDescription: placeholderToNil(dto.type_description),
            code: UpstreamParsing.absentIfBlank(dto.code?.rawValue),
            fillReading: fill,
            lastCollectionAt: dto.last_collection_at,
            lastWashingAt: dto.last_washing_at
        )
    }

    static func placeholderToNil(_ value: String?) -> String? {
        guard let trimmed = UpstreamParsing.absentIfBlank(value) else { return nil }
        let key = WasteCategoryGrouping.key(for: trimmed)
        if key == "n/a" || key == "na" || key == "-" { return nil }
        return trimmed
    }
}

/// Report and resolve bodies. The collection-point id, the issue category, and
/// the type. Coordinates and any installation id stay off this payload.
struct APICommunityWriteBody: Encodable {
    var ecoponto_id: String
    var issue: String
    var kind: String
}
