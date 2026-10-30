import ReciclarCore
import SwiftUI

struct StatsTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                if let statistics = model.statistics {
                    statsList(statistics)
                } else if model.statsStatus == .loading {
                    Section {
                        ProgressView("A carregar estatísticas…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if model.statsError != nil {
                    Section {
                        Text(model.statsError ?? "")
                            .foregroundStyle(.secondary)
                        Button("Tentar novamente") {
                            Task { await model.refreshStatistics(force: true) }
                        }
                    }
                }

                if let error = model.statsError, model.statistics != nil {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Estatísticas")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await model.refreshStatistics(force: true) }
            .overlay {
                if model.statistics == nil, model.statsStatus == .idle, model.statsError == nil {
                    ContentUnavailableView(
                        "Sem estatísticas",
                        systemImage: "number",
                        description: Text("Puxa para atualizar quando houver ligação.")
                    )
                }
            }
        }
        .task {
            await model.refreshStatistics(force: false)
        }
    }

    @ViewBuilder
    private func statsList(_ statistics: CatalogStatistics) -> some View {
        Section("Ecopontos") {
            StatsRow(label: "Total", value: StatsFormat.integer(statistics.locations.total))
            StatsRow(label: "Distritos cobertos", value: StatsFormat.integer(statistics.locations.districts))
            StatsRow(label: "Concelhos cobertos", value: StatsFormat.integer(statistics.locations.municipalities))
            if statistics.locations.operators > 0 {
                StatsRow(label: "Operadores", value: StatsFormat.integer(statistics.locations.operators))
            }
        }

        if let containers = statistics.containers {
            Section("Contentores para reciclagem") {
                StatsRow(label: "Total", value: StatsFormat.integer(containers.total))
                if statistics.locations.total > 0 {
                    StatsRow(label: "Média por ecoponto", value: StatsFormat.decimal(Double(containers.total) / Double(statistics.locations.total)))
                }
                ForEach(containers.byStream) { stream in
                    StatsRow(label: stream.name, value: StatsFormat.integer(stream.count))
                }

            }
        }

        if statistics.containers == nil {
            Section("Contentores para reciclagem") {
                Text("A fonte ainda não disponibilizou a contagem de contentores por material.")
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            Text("Estes números descrevem a rede de recolha. A fonte não fornece toneladas recicladas nem taxas de reciclagem.")
                .font(.footnote).foregroundStyle(.secondary)
        }

        if showsDistrictBreakdown(statistics) {
            Section("Ecopontos por distrito") {
                ForEach(statistics.districts) { district in
                    StatsRow(
                        label: PortuguesePlaceName.district(district.name),
                        value: StatsFormat.integer(district.locationCount)
                    )
                }
            }
        }

        Section("Densidade da rede registada") {
            StatsRow(label: "Por 100 km de estrada", value: StatsFormat.decimal(statistics.density.locationsPer100RoadKm))
            StatsRow(label: "Por km²", value: StatsFormat.decimal(statistics.density.locationsPerKm2))
            Text("Calculada com a área e a rede rodoviária de Portugal, incluindo zonas sem cobertura da fonte.")
                .font(.footnote).foregroundStyle(.secondary)
        }

        Section {
            Text(disclaimer(for: statistics))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 8, trailing: 4))
        }
    }

    private func showsDistrictBreakdown(_ statistics: CatalogStatistics) -> Bool {
        let total = statistics.districts.reduce(0) { $0 + $1.locationCount }
        return total > 0 && total == statistics.locations.total
    }

    private func disclaimer(for statistics: CatalogStatistics) -> String {
        var parts: [String] = []
        if statistics.isFixtureData {
            parts.append(DevelopmentFixtures.bannerText)
        } else {
            parts.append(statistics.coverageNote)
        }
        if let asOf = statistics.asOf {
            parts.append("Fonte sincronizada \(PortugueseRelativeTime.phrase(from: asOf, now: model.now)).")
        }
        return parts.joined(separator: " ")
    }
}

private struct StatsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 12)
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }
}

enum StatsFormat {
    private static let integers: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_PT")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let decimals: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_PT")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func integer(_ value: Int) -> String {
        integers.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func decimal(_ value: Double) -> String {
        decimals.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func percent(_ value: Int) -> String {
        "\(integer(value)) %"
    }

    static func kilometers(_ value: Double) -> String {
        "\(integer(Int(value.rounded()))) km"
    }

    static func squareKilometers(_ value: Double) -> String {
        "\(integer(Int(value.rounded()))) km²"
    }
}

#Preview {
    PreviewStats()
}

private struct PreviewStats: View {
    @State private var model = AppModel(
        dependencies: .preview(),
        locationService: UserLocationService()
    )

    var body: some View {
        StatsTabView()
            .environment(model)
            .environment(\.locale, Locale(identifier: "pt_PT"))
            .task { await model.start() }
    }
}
