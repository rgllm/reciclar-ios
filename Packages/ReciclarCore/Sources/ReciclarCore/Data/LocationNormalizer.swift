import Foundation

public struct NormalizationWarning: Equatable, Sendable {
    public var locationID: String?
    public var message: String

    public init(locationID: String? = nil, message: String) {
        self.locationID = locationID
        self.message = message
    }
}

public struct NormalizationResult: Sendable {
    public var locations: [Ecoponto]
    public var warnings: [NormalizationWarning]

    public init(locations: [Ecoponto], warnings: [NormalizationWarning]) {
        self.locations = locations
        self.warnings = warnings
    }
}

public enum LocationNormalizer {
    public static func decode(from data: Data, provenance: DataProvenance) throws -> NormalizationResult {
        let locations: [UpstreamLocationDTO]
        if let array = try? JSONDecoder().decode([UpstreamLocationDTO].self, from: data) {
            locations = array
        } else {
            locations = [try JSONDecoder().decode(UpstreamLocationDTO.self, from: data)]
        }
        return normalize(locations, provenance: provenance)
    }

    static func normalize(
        _ dtos: [UpstreamLocationDTO],
        provenance: DataProvenance
    ) -> NormalizationResult {
        var result: [Ecoponto] = []
        var warnings: [NormalizationWarning] = []
        var seen = [String: Coordinate]()

        for dto in dtos {
            let id = dto.idlocal.rawValue
            let coordinate = Coordinate(latitude: dto.latitude, longitude: dto.longitude)
            guard coordinate.isValid else {
                warnings.append(NormalizationWarning(locationID: id, message: "Invalid coordinates"))
                continue
            }

            if let existing = seen[id] {
                if existing == coordinate {
                    warnings.append(NormalizationWarning(locationID: id, message: "Duplicate record skipped"))
                } else {
                    warnings.append(
                        NormalizationWarning(
                            locationID: id,
                            message: "Duplicate identifier with different coordinates; kept the first record"
                        )
                    )
                }
                continue
            }

            let containers = dto.Containers.map { container in
                normalize(container: container)
            }
            if containers.isEmpty {
                warnings.append(NormalizationWarning(locationID: id, message: "Location has no containers"))
            }

            seen[id] = coordinate
            result.append(
                Ecoponto(
                    id: id,
                    concessionaireID: UpstreamParsing.absentIfBlank(dto.id_concessionaire?.rawValue),
                    coordinate: coordinate,
                    district: UpstreamParsing.absentIfBlank(dto.distrito),
                    municipality: UpstreamParsing.absentIfBlank(dto.concelho),
                    parish: UpstreamParsing.absentIfBlank(dto.freguesia),
                    locality: UpstreamParsing.absentIfBlank(dto.localidade),
                    address: UpstreamParsing.absentIfBlank(dto.localaddress),
                    locationDescription: UpstreamParsing.absentIfBlank(dto.localdescription)
                        ?? UpstreamParsing.absentIfBlank(dto.ltdescription)
                        ?? UpstreamParsing.absentIfBlank(dto.description),
                    containers: containers,
                    provenance: provenance
                )
            )
        }

        return NormalizationResult(locations: result, warnings: warnings)
    }

    private static func normalize(container dto: UpstreamContainerDTO) -> Container {
        let name = UpstreamParsing.absentIfBlank(dto.waste_desc) ?? "Categoria \(dto.idwaste_type.rawValue)"
        let percent = UpstreamParsing.parsePercent(dto.lastreadingvolume)
        let readingDate = UpstreamParsing.parseTimestamp(dto.timeoflastreading_ts)
        let reading: FillReading?
        if let percent, let readingDate {
            reading = FillReading(percentFull: percent, recordedAt: readingDate)
        } else {
            reading = nil
        }

        return Container(
            id: dto.idcontainer_sensor.rawValue,
            category: WasteCategory(id: WasteCategory.ID(dto.idwaste_type.rawValue), name: name),
            colorToken: UpstreamParsing.absentIfBlank(dto.waste_color),
            volumeLitres: UpstreamParsing.parseLitres(dto.containertype_volume),
            typeDescription: UpstreamParsing.absentIfBlank(dto.containertype_desc),
            code: UpstreamParsing.absentIfBlank(dto.codeler?.rawValue),
            fillReading: reading,
            lastCollectionAt: UpstreamParsing.parseTimestamp(dto.timeoflastcollection_ts),
            lastWashingAt: UpstreamParsing.parseTimestamp(dto.timeoflastwashing_ts)
        )
    }
}

public enum FixtureResource {
    public static func sampleLocationPayloadJSON() throws -> Data {
        try data(named: "sample-location-payload")
    }

    public static func sampleAPILocationsPageJSON() throws -> Data {
        try data(named: "sample-api-locations-page")
    }

    private static func data(named name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw ReciclarAPIError.invalidResponse
        }
        return try Data(contentsOf: url)
    }
}
