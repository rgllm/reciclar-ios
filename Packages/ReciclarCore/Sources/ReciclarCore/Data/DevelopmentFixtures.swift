import Foundation

public enum DevelopmentFixtures {
    public static let bannerText = "Dados de exemplo para desenvolvimento. Não são cobertura real."

    public static func snapshot(at now: Date, extraEvents: [CommunityEvent] = []) -> LocationSnapshot {
        let hour: TimeInterval = 60 * 60
        let glass = WasteCategory.sampleGlass
        let paper = WasteCategory.samplePaper
        let packaging = WasteCategory.samplePackaging

        func container(
            id: String,
            category: WasteCategory,
            color: String,
            percent: Int?,
            age: TimeInterval?
        ) -> Container {
            let reading: FillReading?
            if let percent, let age {
                reading = FillReading(percentFull: percent, recordedAt: now.addingTimeInterval(-age))
            } else {
                reading = nil
            }
            return Container(
                id: id,
                category: category,
                colorToken: color,
                volumeLitres: 2500,
                typeDescription: "Ecoponto",
                fillReading: reading
            )
        }

        let locations = [
            Ecoponto(
                id: "dev-north",
                concessionaireID: "OP-7",
                coordinate: Coordinate(latitude: 10.0000, longitude: 10.0000),
                district: "Distrito Exemplo",
                municipality: "Concelho Exemplo",
                parish: "Freguesia Norte",
                locality: "Norte",
                containers: [
                    container(id: "north-glass", category: glass, color: "Verde", percent: 22, age: 2 * hour),
                    container(id: "north-pack", category: packaging, color: "Amarelo", percent: 40, age: 2 * hour),
                    container(id: "north-paper", category: paper, color: "Azul", percent: 18, age: 2 * hour),
                ],
                provenance: .developmentFixture
            ),
            Ecoponto(
                id: "dev-south",
                concessionaireID: "OP-7",
                coordinate: Coordinate(latitude: 9.9923, longitude: 9.9881),
                district: "Distrito Exemplo",
                municipality: "Concelho Exemplo",
                parish: "Freguesia Sul",
                locality: "Sul",
                containers: [
                    container(id: "south-glass", category: glass, color: "Verde", percent: 91, age: 3 * hour),
                    container(id: "south-pack", category: packaging, color: "Amarelo", percent: 95, age: 3 * hour),
                    container(id: "south-paper", category: paper, color: "Azul", percent: 90, age: 3 * hour),
                ],
                provenance: .developmentFixture
            ),
            Ecoponto(
                id: "dev-east",
                concessionaireID: "OP-7",
                coordinate: Coordinate(latitude: 9.9961, longitude: 10.0163),
                district: "Distrito Exemplo",
                municipality: "Concelho Exemplo",
                parish: "Freguesia Este",
                locality: "Este",
                containers: [
                    container(id: "east-glass", category: glass, color: "Verde", percent: 30, age: 30 * hour),
                    container(id: "east-pack", category: packaging, color: "Amarelo", percent: 12, age: 1 * hour),
                ],
                provenance: .developmentFixture
            ),
            Ecoponto(
                id: "dev-west",
                concessionaireID: "OP-7",
                coordinate: Coordinate(latitude: 9.9994, longitude: 10.0117),
                district: "Distrito Exemplo",
                municipality: "Concelho Exemplo",
                parish: "Freguesia Oeste",
                locality: "Oeste",
                containers: [
                    container(id: "west-glass", category: glass, color: "Verde", percent: nil, age: nil),
                    container(id: "west-pack", category: packaging, color: "Amarelo", percent: nil, age: nil),
                    container(id: "west-paper", category: paper, color: "Azul", percent: nil, age: nil),
                ],
                provenance: .developmentFixture
            ),
            Ecoponto(
                id: "dev-central",
                concessionaireID: "OP-7",
                coordinate: Coordinate(latitude: 9.9808, longitude: 9.9810),
                district: "Distrito Exemplo",
                municipality: "Concelho Exemplo",
                parish: "Freguesia Centro",
                locality: "Centro",
                containers: [
                    container(id: "central-glass", category: glass, color: "Verde", percent: 10, age: -2 * hour),
                    container(id: "central-paper", category: paper, color: "Azul", percent: 44, age: 4 * hour),
                ],
                provenance: .developmentFixture
            ),
            Ecoponto(
                id: "dev-ridge",
                concessionaireID: "OP-7",
                coordinate: Coordinate(latitude: 10.0086, longitude: 10.0151),
                district: "Distrito Exemplo",
                municipality: "Concelho Exemplo",
                parish: "Freguesia Cume",
                locality: "Cume",
                containers: [
                    container(id: "ridge-glass", category: glass, color: "Verde", percent: 55, age: 5 * hour),
                    container(id: "ridge-pack", category: packaging, color: "Amarelo", percent: 60, age: 5 * hour),
                    container(id: "ridge-paper", category: paper, color: "Azul", percent: 15, age: 5 * hour),
                ],
                provenance: .developmentFixture
            ),
        ]

        let events = [
            CommunityEvent(
                id: "dev-ridge-vandalism",
                ecopontoID: "dev-ridge",
                issue: .vandalised,
                kind: .report,
                serverTimestamp: now.addingTimeInterval(-6 * 24 * hour)
            ),
            CommunityEvent(
                id: "dev-ridge-rubbish",
                ecopontoID: "dev-ridge",
                issue: .rubbishOutsideContainers,
                kind: .report,
                serverTimestamp: now.addingTimeInterval(-8 * hour)
            ),
            CommunityEvent(
                id: "dev-south-expired",
                ecopontoID: "dev-south",
                issue: .vandalised,
                kind: .report,
                serverTimestamp: now.addingTimeInterval(-8 * 24 * hour)
            ),
        ] + extraEvents

        return LocationSnapshot(
            locations: locations,
            communityEvents: events,
            lastSuccessfulSync: now,
            isFixtureData: true
        )
    }

    public static func statistics(at now: Date) -> CatalogStatistics {
        CatalogStatistics(
            asOf: now,
            syncToken: "mock-token",
            isFixtureData: true,
            coverageNote: bannerText,
            fillNote: "O espaço disponível e as leituras com menos de 24 horas referem-se à data da última sincronização.",
            fillEvaluatedAt: now,
            geography: StatsGeography(areaKm2: 92_227, roadKm: 71_294),
            density: StatsDensity(
                locationsPer100RoadKm: 17.5,
                locationsPerKm2: 0.14,
                withSpacePer100RoadKm: 13.83,
                withSpacePerKm2: 0.11
            ),
            locations: LocationStats(
                total: 12_480,
                districts: 15,
                municipalities: 181,
                operators: 11,
                withSpaceAvailable: 9_860,
                withUsableReading: 10_200,
                withSpacePercent: 79
            ),
            containers: ContainerStats(
                total: 28_640,
                withUsableReading: 18_205,
                withUsableReadingPercent: 64,
                withSpaceAvailable: 16_400,
                byStream: [
                    StreamCount(id: "glass", name: "Embalagens de vidro", count: 9_120),
                    StreamCount(id: "paper", name: "Papel e cartão", count: 9_410),
                    StreamCount(id: "packaging", name: "Mistura de embalagens", count: 10_110),
                ]
            ),
            districts: [
                DistrictStats(name: "Distrito A", locationCount: 2_100, containerCount: 4_800),
                DistrictStats(name: "Distrito B", locationCount: 1_850, containerCount: 4_200),
                DistrictStats(name: "Distrito C", locationCount: 980, containerCount: 2_250),
            ],
            community: CommunityStats(locationsWithVisibleIssues: 0, litterOutsideContainers: 0, vandalized: 0)
        )
    }
}
