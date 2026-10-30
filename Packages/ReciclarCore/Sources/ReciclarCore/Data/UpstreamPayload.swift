import Foundation

struct UpstreamLocationDTO: Decodable {
    var idlocal: FlexibleIdentifier
    var id_concessionaire: FlexibleIdentifier?
    var latitude: Double
    var longitude: Double
    var distrito: String?
    var concelho: String?
    var freguesia: String?
    var localidade: String?
    var localaddress: String?
    var localdescription: String?
    var description: String?
    var ltdescription: String?
    var localgroups: String?
    var branches: String?
    var Containers: [UpstreamContainerDTO]
}

struct UpstreamContainerDTO: Decodable {
    var idcontainer_sensor: FlexibleIdentifier
    var idwaste_type: FlexibleIdentifier
    var waste_desc: String?
    var waste_color: String?
    var description: String?
    var codeler: FlexibleIdentifier?
    var containertype_volume: String?
    var containertype_desc: String?
    var lastreadingvolume: String?
    var timeoflastreading_ts: String?
    var timeoflastcollection_ts: String?
    var timeoflastwashing_ts: String?
    var associatedtime_ts: String?
}

/// Decodes identifiers as strings, including numeric JSON values.
/// Leading zeros only survive when the JSON already used a string.
struct FlexibleIdentifier: Decodable, Hashable {
    var rawValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            rawValue = string
            return
        }
        if let int = try? container.decode(Int.self) {
            rawValue = String(int)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected string or integer identifier"
        )
    }
}

enum UpstreamParsing {
    /// Working default until the API contract includes an offset.
    static let sourceTimeZone = TimeZone(identifier: "Europe/Lisbon")!

    static func absentIfBlank(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func parsePercent(_ raw: String?) -> Int? {
        guard let raw = absentIfBlank(raw) else { return nil }
        var cleaned = raw.replacingOccurrences(of: " ", with: "")
        cleaned = cleaned.replacingOccurrences(of: "%", with: "")
        cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        guard let value = Int(cleaned), (0...100).contains(value) else { return nil }
        return value
    }

    static func parseLitres(_ raw: String?) -> Int? {
        guard let raw = absentIfBlank(raw) else { return nil }
        let match = raw.prefix { $0.isNumber || $0 == "." || $0 == "," }
        let cleaned = String(match).replacingOccurrences(of: ",", with: ".")
        guard let litres = Double(cleaned), litres > 0 else { return nil }
        return Int(litres)
    }

    static func parseTimestamp(_ raw: String?) -> Date? {
        guard let raw = absentIfBlank(raw) else { return nil }
        timestampLock.lock()
        defer { timestampLock.unlock() }
        return timestampFormatter.date(from: raw)
    }
}

private let timestampLock = NSLock()
private let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = UpstreamParsing.sourceTimeZone
    formatter.dateFormat = "dd/MM/yyyy HH:mm"
    return formatter
}()
