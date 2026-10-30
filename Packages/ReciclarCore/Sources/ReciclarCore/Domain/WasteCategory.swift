import Foundation

/// Stable waste-stream identity.
/// Bin colours are presentation only and must not be used as the data model.
public struct WasteCategory: Hashable, Sendable, Codable, Identifiable {
    public var id: ID
    public var name: String

    public init(id: ID, name: String) {
        self.id = id
        self.name = name
    }

    public struct ID: Hashable, Sendable, Codable, RawRepresentable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

extension WasteCategory {
    /// Observed in the supplied sample payload. Not a complete catalogue.
    public static let sampleGlass = WasteCategory(id: ID("2"), name: "Embalagens de Vidro")
    public static let samplePaper = WasteCategory(id: ID("3"), name: "Papel e cartão")
    public static let samplePackaging = WasteCategory(id: ID("4"), name: "Mistura de embalagens")
}

/// Groups live waste-type ids that share a recycling stream.
/// The same stream name can appear with different ids; filters must not require every id.
public enum RecyclingStream: String, Sendable, Hashable, CaseIterable, Identifiable {
    case glass
    case paper
    case packaging

    public var id: String { rawValue }

    public var portugueseLabel: String {
        switch self {
        case .glass: "Embalagens de vidro"
        case .paper: "Papel e cartão"
        case .packaging: "Mistura de embalagens"
        }
    }

    public func matches(name: String) -> Bool {
        let key = WasteCategoryGrouping.key(for: name)
        switch self {
        case .glass:
            return key.contains("vidro")
        case .paper:
            return (key.contains("papel") || key.contains("cartao")) && !key.contains("vidro")
        case .packaging:
            return key.contains("mistura de embalagens")
                || (
                    key.contains("embalagens")
                        && !key.contains("vidro")
                        && !key.contains("papel")
                        && !key.contains("cartao")
                )
        }
    }

    public static func classifying(name: String) -> RecyclingStream? {
        if RecyclingStream.glass.matches(name: name) { return .glass }
        if RecyclingStream.paper.matches(name: name) { return .paper }
        if RecyclingStream.packaging.matches(name: name) { return .packaging }
        return nil
    }
}

public enum WasteCategoryGrouping {
    public static func key(for name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_PT"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum LocationFilterToken: Hashable, Sendable {
    case stream(RecyclingStream)
    case nameKey(String)

    public var id: String {
        switch self {
        case .stream(let stream): "stream:\(stream.rawValue)"
        case .nameKey(let key): "name:\(key)"
        }
    }
}

public struct WasteFilterChip: Identifiable, Hashable, Sendable {
    public var token: LocationFilterToken
    public var name: String
    public var categoryIDs: Set<WasteCategory.ID>

    public var id: String { token.id }

    public init(token: LocationFilterToken, name: String, categoryIDs: Set<WasteCategory.ID>) {
        self.token = token
        self.name = name
        self.categoryIDs = categoryIDs
    }

    public static func chips(from locations: [Ecoponto]) -> [WasteFilterChip] {
        var streamNames: [RecyclingStream: [String]] = [:]
        var streamIDs: [RecyclingStream: Set<WasteCategory.ID>] = [:]
        var otherNames: [String: String] = [:]
        var otherIDs: [String: Set<WasteCategory.ID>] = [:]

        for location in locations {
            for category in location.acceptedCategories {
                if let stream = RecyclingStream.classifying(name: category.name) {
                    streamNames[stream, default: []].append(category.name)
                    streamIDs[stream, default: []].insert(category.id)
                } else {
                    let key = WasteCategoryGrouping.key(for: category.name)
                    if otherNames[key] == nil {
                        otherNames[key] = category.name
                    }
                    otherIDs[key, default: []].insert(category.id)
                }
            }
        }

        var chips: [WasteFilterChip] = []
        for stream in RecyclingStream.allCases {
            guard let ids = streamIDs[stream], !ids.isEmpty else { continue }
            let title = mostFrequent(streamNames[stream] ?? []) ?? stream.portugueseLabel
            chips.append(WasteFilterChip(token: .stream(stream), name: title, categoryIDs: ids))
        }
        for key in otherNames.keys.sorted() {
            guard let name = otherNames[key], let ids = otherIDs[key] else { continue }
            chips.append(WasteFilterChip(token: .nameKey(key), name: name, categoryIDs: ids))
        }
        return chips
    }

    private static func mostFrequent(_ names: [String]) -> String? {
        var counts: [String: Int] = [:]
        var original: [String: String] = [:]
        for name in names {
            let key = WasteCategoryGrouping.key(for: name)
            counts[key, default: 0] += 1
            if original[key] == nil {
                original[key] = name
            }
        }
        return counts.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key > rhs.key
            }
            return lhs.value < rhs.value
        }.flatMap { original[$0.key] }
    }
}
