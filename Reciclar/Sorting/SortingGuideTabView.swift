import ReciclarCore
import SwiftUI

struct SortingGuideTabView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var selectedFilter: SortingGuideFilter = .all

    var body: some View {
        NavigationStack {
            List {
                if filteredEntries.isEmpty {
                    ContentUnavailableView.search(text: query.isEmpty ? selectedFilter.title : query)
                } else {
                    ForEach(groupedEntries, id: \.destination) { group in
                        Section {
                            ForEach(group.entries, id: \.id) { entry in
                                NavigationLink(value: entry.id) {
                                    SortingGuideRow(entry: entry)
                                }
                            }
                        } header: {
                            SortingGuideSectionHeader(
                                title: group.destination,
                                categoryID: group.categoryID,
                                isOutOfScope: group.isOutOfScope
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Reciclagem")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { entryID in
                if let entry = model.sortingCatalog.entries.first(where: { $0.id == entryID }) {
                    SortingGuideDetailView(entry: entry)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Onde deito isto?")
            .safeAreaInset(edge: .top, spacing: 0) {
                filterBar
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SortingGuideFilter.allCases) { filter in
                    MapFilterChip(
                        title: filter.title,
                        systemImage: filter.systemImage,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filtros de reciclagem")
    }

    private var filteredEntries: [SortingEntry] {
        model.sortingCatalog.entries.filter { entry in
            selectedFilter.matches(entry) && matchesQuery(entry)
        }
    }

    private var groupedEntries: [SortingGuideGroup] {
        struct Key: Hashable {
            var title: String
            var categoryID: WasteCategory.ID?
            var isOutOfScope: Bool
            var sortRank: Int
        }

        let grouped = Dictionary(grouping: filteredEntries) { entry -> Key in
            if entry.isOutOfScope {
                return Key(title: "Outros resíduos", categoryID: nil, isOutOfScope: true, sortRank: 100)
            }
            if entry.categoryIDs.contains(WasteCategory.sampleGlass.id) {
                return Key(
                    title: WasteCategory.sampleGlass.name,
                    categoryID: WasteCategory.sampleGlass.id,
                    isOutOfScope: false,
                    sortRank: 0
                )
            }
            if entry.categoryIDs.contains(WasteCategory.samplePaper.id) {
                return Key(
                    title: WasteCategory.samplePaper.name,
                    categoryID: WasteCategory.samplePaper.id,
                    isOutOfScope: false,
                    sortRank: 1
                )
            }
            if entry.categoryIDs.contains(WasteCategory.samplePackaging.id) {
                return Key(
                    title: WasteCategory.samplePackaging.name,
                    categoryID: WasteCategory.samplePackaging.id,
                    isOutOfScope: false,
                    sortRank: 2
                )
            }
            return Key(title: entry.destination, categoryID: entry.categoryIDs.first, isOutOfScope: false, sortRank: 50)
        }

        return grouped.keys
            .sorted { lhs, rhs in
                if lhs.sortRank != rhs.sortRank { return lhs.sortRank < rhs.sortRank }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            .map { key in
                SortingGuideGroup(
                    destination: key.title,
                    entries: (grouped[key] ?? []).sorted {
                        $0.canonicalName.localizedStandardCompare($1.canonicalName) == .orderedAscending
                    },
                    categoryID: key.categoryID,
                    isOutOfScope: key.isOutOfScope
                )
            }
    }

    private func matchesQuery(_ entry: SortingEntry) -> Bool {
        entry.matchesSearch(query)
    }
}

private struct SortingGuideGroup {
    var destination: String
    var entries: [SortingEntry]
    var categoryID: WasteCategory.ID?
    var isOutOfScope: Bool
}

private enum SortingGuideFilter: String, CaseIterable, Identifiable {
    case all
    case glass
    case paper
    case packaging
    case outOfScope

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Todos"
        case .glass: "Vidro"
        case .paper: "Papel"
        case .packaging: "Embalagens"
        case .outOfScope: "Outros"
        }
    }

    var systemImage: String? {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .glass: "wineglass"
        case .paper: "newspaper"
        case .packaging: "shippingbox"
        case .outOfScope: "info.circle"
        }
    }

    private static let ecopontoStreams: Set<WasteCategory.ID> = [
        WasteCategory.sampleGlass.id,
        WasteCategory.samplePaper.id,
        WasteCategory.samplePackaging.id,
    ]

    func matches(_ entry: SortingEntry) -> Bool {
        switch self {
        case .all:
            true
        case .glass:
            !entry.isOutOfScope && entry.categoryIDs.contains(WasteCategory.sampleGlass.id)
        case .paper:
            !entry.isOutOfScope && entry.categoryIDs.contains(WasteCategory.samplePaper.id)
        case .packaging:
            !entry.isOutOfScope && entry.categoryIDs.contains(WasteCategory.samplePackaging.id)
        case .outOfScope:
            entry.isOutOfScope || entry.categoryIDs.isDisjoint(with: SortingGuideFilter.ecopontoStreams)
        }
    }
}

private struct SortingGuideSectionHeader: View {
    let title: String
    let categoryID: WasteCategory.ID?
    let isOutOfScope: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accentColor)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
        .accessibilityElement(children: .combine)
    }

    private var accentColor: Color {
        if isOutOfScope { return .secondary }
        guard let categoryID else { return .secondary }
        return WasteCategoryPresentation.color(
            for: WasteCategory(id: categoryID, name: title)
        )
    }

    private var systemImage: String {
        if isOutOfScope { return "info.circle" }
        guard let categoryID else { return "arrow.3.trianglepath" }
        return WasteCategoryPresentation.symbol(
            for: WasteCategory(id: categoryID, name: title)
        )
    }
}

private struct SortingGuideRow: View {
    let entry: SortingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.canonicalName.capitalizedSentence)
                .font(.body.weight(.medium))
            Text(entry.isOutOfScope ? "Outros resíduos" : entry.destination)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.canonicalName.capitalizedSentence). \(entry.isOutOfScope ? "Outros resíduos" : entry.destination)")
    }
}

struct SortingGuideDetailView: View {
    @Environment(AppModel.self) private var model
    let entry: SortingEntry

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text(entry.isOutOfScope ? "Fora das recolhas deste guia" : entry.destination)
                            .font(.title3.weight(.semibold))
                    } icon: {
                        Image(systemName: destinationSymbol)
                            .foregroundStyle(destinationColor)
                    }
                    .labelStyle(.titleAndIcon)

                    if !entry.preparation.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Preparação")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(entry.preparation, id: \.self) { step in
                                Text(step)
                                    .font(.body)
                            }
                        }
                    }

                    if !entry.exceptions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Atenção")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(entry.exceptions, id: \.self) { item in
                                Text(item)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let clarification = entry.clarification {
                        Text(clarification)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if !entry.isOutOfScope, !entry.categoryIDs.isEmpty {
                Section {
                    Button {
                        model.openMap(categories: entry.categoryIDs)
                    } label: {
                        Label("Ver no mapa", systemImage: "map")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }

            if !entry.isOutOfScope, entry.categoryIDs.isEmpty {
                Section {
                    Text("Este destino não faz parte do mapa de ecopontos.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !entry.sources.isEmpty {
                Section("Fontes") {
                    ForEach(entry.sources) { source in
                        Link(destination: source.url) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.title)
                                Text(source.url.absoluteString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                if let reviewed = source.reviewedOn {
                                    Text("Revisto em \(reviewed.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(source.geographicScope)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityHint("Abre a fonte")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(entry.canonicalName.capitalizedSentence)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var destinationSymbol: String {
        if entry.isOutOfScope { return "info.circle" }
        guard let categoryID = entry.categoryIDs.first else {
            let folded = entry.destination.folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: Locale(identifier: "pt_PT")
            )
            if folded.contains("pilha") { return "battery.100" }
            if folded.contains("oleao") { return "drop.fill" }
            if folded.contains("volta") { return "arrow.uturn.backward.circle" }
            if folded.contains("farmacia") { return "cross.case" }
            if folded.contains("lampada") || folded.contains("eletric") { return "lightbulb" }
            if folded.contains("ecocentro") || folded.contains("comerciante") || folded.contains("monos") {
                return "building.2"
            }
            if folded.contains("indiferenciado") || folded.contains("lixo comum") { return "trash" }
            return "arrow.triangle.2.circlepath"
        }
        return WasteCategoryPresentation.symbol(for: WasteCategory(id: categoryID, name: entry.destination))
    }

    private var destinationColor: Color {
        if entry.isOutOfScope { return .secondary }
        guard let categoryID = entry.categoryIDs.first else { return .secondary }
        return WasteCategoryPresentation.color(for: WasteCategory(id: categoryID, name: entry.destination))
    }
}

private extension String {
    var capitalizedSentence: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

#Preview {
    PreviewRoot()
}

private struct PreviewRoot: View {
    @State private var model = AppModel(
        dependencies: .preview(),
        locationService: UserLocationService()
    )

    var body: some View {
        SortingGuideTabView()
            .environment(model)
            .environment(\.locale, Locale(identifier: "pt_PT"))
    }
}
