import Foundation

public struct GuidanceSource: Hashable, Sendable, Codable, Identifiable {
    public var id: String
    public var title: String
    public var url: URL
    public var geographicScope: String
    public var reviewedOn: Date?

    public init(
        id: String,
        title: String,
        url: URL,
        geographicScope: String,
        reviewedOn: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.geographicScope = geographicScope
        self.reviewedOn = reviewedOn
    }
}

public enum AssistantAnswerKind: String, Sendable, Equatable {
    case curatedCatalog
    case model
}

public enum AssistantServiceAvailability: Equatable, Sendable {
    case ready
    case unavailable(AssistantUnavailability)
}

public enum AssistantUnavailability: Equatable, Sendable {
    case deviceNotEligible
    case appleIntelligenceOff
    case modelNotReady
    case localeUnsupported
    case unknown

    public var portugueseExplanation: String {
        switch self {
        case .deviceNotEligible:
            "Este aparelho não tem o modelo da Apple Intelligence."
        case .appleIntelligenceOff:
            "Ativa a Apple Intelligence nas Definições para usar o modelo no aparelho."
        case .modelNotReady:
            "O modelo ainda está a descarregar. Podes tentar daqui a pouco."
        case .localeUnsupported:
            "O modelo neste aparelho não está disponível em português europeu."
        case .unknown:
            "O modelo da Apple Intelligence não está disponível neste momento."
        }
    }
}

public struct AssistantReply: Equatable, Sendable {
    public var destination: String
    public var preparation: [String]
    public var exceptions: [String]
    public var clarification: String?
    public var sources: [GuidanceSource]
    public var kind: AssistantAnswerKind
    public var mapCategories: Set<WasteCategory.ID>
    public var isOutOfScope: Bool
    public var catalogVersion: String
    public var isRetryable: Bool

    public init(
        destination: String,
        preparation: [String] = [],
        exceptions: [String] = [],
        clarification: String? = nil,
        sources: [GuidanceSource] = [],
        kind: AssistantAnswerKind,
        mapCategories: Set<WasteCategory.ID> = [],
        isOutOfScope: Bool = false,
        catalogVersion: String,
        isRetryable: Bool = false
    ) {
        self.destination = destination
        self.preparation = preparation
        self.exceptions = exceptions
        self.clarification = clarification
        self.sources = sources
        self.kind = kind
        self.mapCategories = mapCategories
        self.isOutOfScope = isOutOfScope
        self.catalogVersion = catalogVersion
        self.isRetryable = isRetryable
    }
}

public protocol SortingAssistant: Sendable {
    func availability() async -> AssistantServiceAvailability
    func prepare() async
    func resetConversation() async
    func answer(_ question: String) async -> AssistantReply
}

extension SortingAssistant {
    public func availability() async -> AssistantServiceAvailability { .ready }
    public func prepare() async {}
    public func resetConversation() async {}
}

public struct SortingEntry: Sendable {
    public var id: String
    public var canonicalName: String
    public var aliases: [String]
    public var destination: String
    public var preparation: [String]
    public var exceptions: [String]
    public var clarification: String?
    public var categoryIDs: Set<WasteCategory.ID>
    public var isOutOfScope: Bool
    public var sources: [GuidanceSource]

    public init(
        id: String,
        canonicalName: String,
        aliases: [String],
        destination: String,
        preparation: [String] = [],
        exceptions: [String] = [],
        clarification: String? = nil,
        categoryIDs: Set<WasteCategory.ID> = [],
        isOutOfScope: Bool = false,
        sources: [GuidanceSource] = []
    ) {
        self.id = id
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.destination = destination
        self.preparation = preparation
        self.exceptions = exceptions
        self.clarification = clarification
        self.categoryIDs = categoryIDs
        self.isOutOfScope = isOutOfScope
        self.sources = sources
    }
    public func matchesSearch(_ query: String) -> Bool {
        let words = CatalogSortingAssistant.normalize(query).split(whereSeparator: { $0.isWhitespace })
        let text = CatalogSortingAssistant.normalize(([canonicalName, destination] + aliases).joined(separator: " "))
        return words.allSatisfy { text.contains($0) }
    }

}

public struct SortingCatalog: Sendable {
    public var version: String
    public var entries: [SortingEntry]
    public var sources: [GuidanceSource]

    public init(version: String, entries: [SortingEntry], sources: [GuidanceSource]) {
        self.version = version
        self.entries = entries
        self.sources = sources
    }

    public var allowedCategoryIDs: Set<WasteCategory.ID> {
        Set(entries.filter { !$0.isOutOfScope }.flatMap(\.categoryIDs))
    }

    public func source(id: String) -> GuidanceSource? {
        sources.first { $0.id == id } ?? entries.flatMap(\.sources).first { $0.id == id }
    }

    public func sources(for categoryID: WasteCategory.ID) -> [GuidanceSource] {
        var seen = Set<String>()
        var result: [GuidanceSource] = []
        for entry in entries where !entry.isOutOfScope && entry.categoryIDs.contains(categoryID) {
            for source in entry.sources where seen.insert(source.id).inserted {
                result.append(source)
            }
        }
        return result
    }

    /// Trusted briefing for model instructions. Does not include user text.
    public var modelBriefing: String {
        var lines: [String] = [
            "Catálogo \(version).",
            "Só podes indicar estes fluxos de ecoponto:",
            "- 2 Embalagens de vidro",
            "- 3 Papel e cartão",
            "- 4 Mistura de embalagens",
            "Itens:",
        ]
        for entry in entries {
            let aliases = ([entry.canonicalName] + entry.aliases).joined(separator: ", ")
            let codes = entry.categoryIDs.map(\.rawValue).joined(separator: ",")
            let scope = entry.isOutOfScope ? "FORA_DE_AMBITO" : "ECOPONTO:\(codes)"
            lines.append("- \(aliases) -> \(scope). Destino: \(entry.destination).")
            if !entry.preparation.isEmpty {
                lines.append("  Preparação: \(entry.preparation.joined(separator: " "))")
            }
            if !entry.exceptions.isEmpty {
                lines.append("  Exceções: \(entry.exceptions.joined(separator: " "))")
            }
            if !entry.sources.isEmpty {
                lines.append("  Fontes: \(entry.sources.map(\.id).joined(separator: ", "))")
            }
        }
        lines.append("Fontes permitidas (não inventes URLs):")
        for source in sources {
            lines.append("- \(source.id): \(source.title) \(source.url.absoluteString) [\(source.geographicScope)]")
        }
        return lines.joined(separator: "\n")
    }
}

public enum AssistantReplySanitizer {
    public static func makeReply(
        destination: String,
        preparation: [String],
        exceptions: [String],
        clarification: String?,
        proposedCategoryIDs: [String],
        citedSourceIDs: [String],
        isOutOfScope: Bool,
        kind: AssistantAnswerKind,
        catalog: SortingCatalog,
        isRetryable: Bool = false
    ) -> AssistantReply {
        let trimmedClarification = clarification?.trimmingCharacters(in: .whitespacesAndNewlines)
        let categories: Set<WasteCategory.ID>
        if isOutOfScope {
            categories = []
        } else {
            categories = Set(
                proposedCategoryIDs
                    .map { WasteCategory.ID($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    .filter { catalog.allowedCategoryIDs.contains($0) }
            )
        }

        var sources: [GuidanceSource] = []
        var seen = Set<String>()
        for id in citedSourceIDs {
            if let source = catalog.source(id: id), seen.insert(source.id).inserted {
                sources.append(source)
            }
        }
        if sources.isEmpty, let category = categories.first {
            sources = catalog.sources(for: category)
        }

        return AssistantReply(
            destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
            preparation: preparation.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            exceptions: exceptions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            clarification: trimmedClarification?.isEmpty == false ? trimmedClarification : nil,
            sources: sources,
            kind: kind,
            mapCategories: categories,
            isOutOfScope: isOutOfScope,
            catalogVersion: catalog.version,
            isRetryable: isRetryable
        )
    }
}

public struct CatalogSortingAssistant: SortingAssistant {
    private let catalog: SortingCatalog

    public init(catalog: SortingCatalog = .development) {
        self.catalog = catalog
    }

    public func answer(_ question: String) async -> AssistantReply {
        let query = Self.normalize(question)
        guard !query.isEmpty else {
            return AssistantReply(
                destination: "Escreve o que queres deitar fora.",
                kind: .curatedCatalog,
                catalogVersion: catalog.version
            )
        }

        let scored = catalog.entries.compactMap { entry -> (SortingEntry, Int)? in
            let score = Self.score(query: query, entry: entry)
            return score > 0 ? (entry, score) : nil
        }
        .sorted { $0.1 > $1.1 }

        guard let best = scored.first else {
            return AssistantReply(
                destination: "Ainda não tenho uma indicação segura para isto.",
                clarification: "Podes descrever o material? Por exemplo: plástico, vidro, papel ou metal.",
                kind: .curatedCatalog,
                catalogVersion: catalog.version
            )
        }

        if scored.count > 1, scored[1].1 == best.1 {
            return AssistantReply(
                destination: "Preciso de um pormenor para não te indicar o contentor errado.",
                clarification: "É \(best.0.canonicalName) ou \(scored[1].0.canonicalName)?",
                kind: .curatedCatalog,
                catalogVersion: catalog.version
            )
        }

        let entry = best.0
        if entry.isOutOfScope {
            return AssistantReply(
                destination: "Isto está fora do âmbito desta versão da app.",
                preparation: [],
                exceptions: entry.exceptions,
                clarification: entry.clarification,
                sources: entry.sources,
                kind: .curatedCatalog,
                isOutOfScope: true,
                catalogVersion: catalog.version
            )
        }

        return AssistantReply(
            destination: entry.destination,
            preparation: entry.preparation,
            exceptions: entry.exceptions,
            clarification: entry.clarification,
            sources: entry.sources,
            kind: .curatedCatalog,
            mapCategories: entry.categoryIDs,
            catalogVersion: catalog.version
        )
    }

    public static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_PT"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func score(query: String, entry: SortingEntry) -> Int {
        let names = ([entry.canonicalName] + entry.aliases).map(normalize)
        if names.contains(where: { $0 == query }) { return 100 }
        if names.contains(where: { query.contains($0) || $0.contains(query) }) { return 80 }
        let queryTokens = Set(query.split { !$0.isLetter }.map(String.init).filter { $0.count > 2 })
        guard !queryTokens.isEmpty else { return 0 }
        let aliasTokens = Set(
            names.joined(separator: " ").split { !$0.isLetter }.map(String.init).filter { $0.count > 2 }
        )
        let overlap = queryTokens.intersection(aliasTokens).count
        return overlap >= 2 ? 60 : (overlap == 1 ? 30 : 0)
    }
}

private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.timeZone = TimeZone(identifier: "Europe/Lisbon")
    return Calendar(identifier: .gregorian).date(from: components) ?? Date.distantPast
}
