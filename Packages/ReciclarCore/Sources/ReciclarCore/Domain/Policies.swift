import Foundation

public enum FillEvidence: Equatable, Sendable {
    case none
    case usable(percentFull: Int, recordedAt: Date)
}

/// How a reading or ecoponto may be described. Missing evidence is never available.
public enum SpaceAvailability: Equatable, Sendable {
    /// Usable fullness strictly below 90%.
    case available
    /// Usable fullness at or above 90%.
    case noSpace
    /// No usable reading. Do not present this as available.
    case unknown
}

public struct LocationSpaceStatus: Equatable, Sendable {
    public var availability: SpaceAvailability
    /// Lowest usable fullness that supports `availability`. Absent when the status is unknown.
    public var percentFull: Int?

    public init(availability: SpaceAvailability, percentFull: Int?) {
        self.availability = availability
        self.percentFull = percentFull
    }

    /// Copy for the detail sheet when a reading cannot be shown.
    public static let missingReadingExplanation = "Sem leitura recente da ocupação"

    public var portugueseLabel: String {
        switch availability {
        case .available: "Com espaço"
        case .noSpace: "Sem espaço"
        case .unknown: "Sem leitura"
        }
    }

    /// Unknown occupancy stays off the map. The dashed pin is the signal; the phrase is for the detail sheet.
    public var showsMapCaption: Bool {
        availability != .unknown
    }

    /// Shown when the user opens a location or container that has no usable reading.
    public var detailExplanation: String? {
        availability == .unknown ? Self.missingReadingExplanation : nil
    }

    public var accessibilityLabel: String {
        switch availability {
        case .available:
            if let percentFull {
                return "Com espaço disponível, \(percentFull) por cento ocupado"
            }
            return "Com espaço disponível"
        case .noSpace:
            if let percentFull {
                return "Sem espaço disponível, \(percentFull) por cento ocupado"
            }
            return "Sem espaço disponível"
        case .unknown:
            return "Ocupação desconhecida"
        }
    }
}

/// Fill indicators come only from validated API readings.
/// Working default: `percentFull` is fullness. Confirm with the API before treating this as contract.
public enum FillReadingPolicy {
    public static let maxAge: TimeInterval = 24 * 60 * 60
    public static let spaceAvailableBelowPercent = 90

    public static func evidence(from reading: FillReading?, at now: Date) -> FillEvidence {
        guard let reading else { return .none }
        guard reading.recordedAt <= now else { return .none }
        guard now.timeIntervalSince(reading.recordedAt) <= maxAge else { return .none }
        return .usable(percentFull: reading.percentFull, recordedAt: reading.recordedAt)
    }

    public static func hasSpaceAvailable(reading: FillReading?, at now: Date) -> Bool {
        availability(of: reading, at: now) == .available
    }

    public static func availability(of reading: FillReading?, at now: Date) -> SpaceAvailability {
        status(of: reading, at: now).availability
    }

    public static func status(of reading: FillReading?, at now: Date) -> LocationSpaceStatus {
        guard case let .usable(percent, _) = evidence(from: reading, at: now) else {
            return LocationSpaceStatus(availability: .unknown, percentFull: nil)
        }
        if percent < spaceAvailableBelowPercent {
            return LocationSpaceStatus(availability: .available, percentFull: percent)
        }
        return LocationSpaceStatus(availability: .noSpace, percentFull: percent)
    }

    /// A location is available when any reading qualifies. A full reading does not
    /// turn a missing reading into available, and missing readings do not count as space.
    public static func status(of readings: [FillReading?], at now: Date) -> LocationSpaceStatus {
        var availablePercents: [Int] = []
        var occupiedPercents: [Int] = []
        for reading in readings {
            let readingStatus = status(of: reading, at: now)
            switch readingStatus.availability {
            case .available:
                if let percent = readingStatus.percentFull { availablePercents.append(percent) }
            case .noSpace:
                if let percent = readingStatus.percentFull { occupiedPercents.append(percent) }
            case .unknown:
                break
            }
        }
        if let lowest = availablePercents.min() {
            return LocationSpaceStatus(availability: .available, percentFull: lowest)
        }
        if let lowest = occupiedPercents.min() {
            return LocationSpaceStatus(availability: .noSpace, percentFull: lowest)
        }
        return LocationSpaceStatus(availability: .unknown, percentFull: nil)
    }
}

public enum CommunityIssuePolicy {
    public static let expiry: TimeInterval = 7 * 24 * 60 * 60

    public static func visibleIssues(
        in events: [CommunityEvent],
        for ecopontoID: String,
        at now: Date
    ) -> [VisibleCommunityIssue] {
        let relevant = events
            .filter { $0.ecopontoID == ecopontoID }
            .sorted { $0.serverTimestamp > $1.serverTimestamp }

        var consumed = Set<CommunityIssueKind>()
        var visible: [VisibleCommunityIssue] = []

        for event in relevant {
            guard consumed.insert(event.issue).inserted else { continue }
            guard event.kind == .report else { continue }
            guard event.serverTimestamp <= now else { continue }
            guard now.timeIntervalSince(event.serverTimestamp) <= expiry else { continue }
            visible.append(VisibleCommunityIssue(kind: event.issue, reportedAt: event.serverTimestamp))
        }

        return visible
    }
}

/// When the interface should next re-read the clock.
/// Fill readings and community reports change at real timestamps. Relative
/// phrases change about once a minute, so a refresh is never more often than that.
public enum FreshnessSchedule {
    /// Earliest future `recordedAt` or 24-hour expiry across fill readings.
    /// `.distantFuture` when every reading is already settled.
    public static func nextFillBoundary(locations: [Ecoponto], now: Date) -> Date {
        var next: Date?
        for location in locations {
            for container in location.containers {
                guard let reading = container.fillReading else { continue }
                consider(reading.recordedAt, now: now, next: &next)
                consider(reading.recordedAt.addingTimeInterval(FillReadingPolicy.maxAge), now: now, next: &next)
            }
        }
        return next ?? .distantFuture
    }

    /// Next fill or community-report transition strictly after `now`.
    public static func nextBoundary(
        locations: [Ecoponto],
        events: [CommunityEvent],
        now: Date
    ) -> Date? {
        var next: Date?
        for location in locations {
            for container in location.containers {
                guard let reading = container.fillReading else { continue }
                consider(reading.recordedAt, now: now, next: &next)
                consider(reading.recordedAt.addingTimeInterval(FillReadingPolicy.maxAge), now: now, next: &next)
            }
        }
        for event in events {
            consider(event.serverTimestamp, now: now, next: &next)
            if event.kind == .report {
                consider(event.serverTimestamp.addingTimeInterval(CommunityIssuePolicy.expiry), now: now, next: &next)
            }
        }
        return next
    }

    /// Wait until the next boundary, but at most one minute, and not before `notBefore`.
    public static func delay(now: Date, notBefore: Date, nextBoundary: Date?) -> TimeInterval {
        var target = now.addingTimeInterval(60)
        if let nextBoundary, nextBoundary > now {
            target = min(target, nextBoundary)
        }
        if target < notBefore {
            target = notBefore
        }
        return min(60, max(0, target.timeIntervalSince(now)))
    }

    private static func consider(_ date: Date, now: Date, next: inout Date?) {
        guard date > now else { return }
        if let current = next, date >= current { return }
        next = date
    }
}

public struct LocationFilter: Equatable, Sendable {
    /// Exact category ids. Each id must be accepted (AND). Used by tests and fixtures.
    public var requiredCategories: Set<WasteCategory.ID>
    /// Live catalog tokens. Multiple tokens still mean AND across streams.
    public var requiredTokens: Set<LocationFilterToken>
    public var requiresSpaceAvailable: Bool

    public init(
        requiredCategories: Set<WasteCategory.ID> = [],
        requiredTokens: Set<LocationFilterToken> = [],
        requiresSpaceAvailable: Bool = false
    ) {
        self.requiredCategories = requiredCategories
        self.requiredTokens = requiredTokens
        self.requiresSpaceAvailable = requiresSpaceAvailable
    }

    public var isActive: Bool {
        !requiredCategories.isEmpty || !requiredTokens.isEmpty || requiresSpaceAvailable
    }

    public mutating func reset() {
        requiredCategories = []
        requiredTokens = []
        requiresSpaceAvailable = false
    }

    public mutating func toggle(_ token: LocationFilterToken) {
        if requiredTokens.contains(token) {
            requiredTokens.remove(token)
        } else {
            requiredTokens.insert(token)
        }
    }

    /// Space for the streams the filter asks for. With no stream selected, any container can qualify.
    /// A required stream without a usable reading stays unknown and is never reported as available.
    public func spaceStatus(of location: Ecoponto, at now: Date) -> LocationSpaceStatus {
        if requiredCategories.isEmpty && requiredTokens.isEmpty {
            return FillReadingPolicy.status(of: location.containers.map(\.fillReading), at: now)
        }

        var parts: [LocationSpaceStatus] = []
        for id in requiredCategories {
            let readings = location.containers.filter { $0.category.id == id }.map(\.fillReading)
            parts.append(FillReadingPolicy.status(of: readings, at: now))
        }
        for token in requiredTokens {
            let readings = location.containers.filter { tokenMatches(token, container: $0) }.map(\.fillReading)
            parts.append(FillReadingPolicy.status(of: readings, at: now))
        }
        if parts.contains(where: { $0.availability == .unknown }) {
            return LocationSpaceStatus(availability: .unknown, percentFull: nil)
        }
        if parts.contains(where: { $0.availability == .noSpace }) {
            return LocationSpaceStatus(availability: .noSpace, percentFull: nil)
        }
        return LocationSpaceStatus(
            availability: .available,
            percentFull: parts.compactMap(\.percentFull).min()
        )
    }

    /// Multiple selected categories match locations that accept all of them.
    public func matches(_ location: Ecoponto, at now: Date) -> Bool {
        let accepted = location.acceptedCategoryIDs
        if !requiredCategories.isSubset(of: accepted) {
            return false
        }
        if !requiredTokens.allSatisfy({ tokenMatches($0, location: location) }) {
            return false
        }

        if requiresSpaceAvailable {
            if requiredCategories.isEmpty && requiredTokens.isEmpty {
                return location.containers.contains {
                    FillReadingPolicy.hasSpaceAvailable(reading: $0.fillReading, at: now)
                }
            }
            let idsOk = requiredCategories.allSatisfy { categoryID in
                location.containers.contains {
                    $0.category.id == categoryID
                        && FillReadingPolicy.hasSpaceAvailable(reading: $0.fillReading, at: now)
                }
            }
            let tokensOk = requiredTokens.allSatisfy { token in
                location.containers.contains { container in
                    tokenMatches(token, container: container)
                        && FillReadingPolicy.hasSpaceAvailable(reading: container.fillReading, at: now)
                }
            }
            return idsOk && tokensOk
        }

        return true
    }

    private func tokenMatches(_ token: LocationFilterToken, location: Ecoponto) -> Bool {
        switch token {
        case .stream(let stream):
            location.acceptedCategories.contains { stream.matches(name: $0.name) }
        case .nameKey(let key):
            location.acceptedCategories.contains { WasteCategoryGrouping.key(for: $0.name) == key }
        }
    }

    private func tokenMatches(_ token: LocationFilterToken, container: Container) -> Bool {
        switch token {
        case .stream(let stream):
            stream.matches(name: container.category.name)
        case .nameKey(let key):
            WasteCategoryGrouping.key(for: container.category.name) == key
        }
    }
}

public struct ProximityPolicy: Equatable, Sendable {
    public var radiusMeters: Double
    public var maxFixAge: TimeInterval
    public var maxHorizontalAccuracy: Double

    public init(
        radiusMeters: Double = 100,
        maxFixAge: TimeInterval = 60,
        maxHorizontalAccuracy: Double = 50
    ) {
        self.radiusMeters = radiusMeters
        self.maxFixAge = maxFixAge
        self.maxHorizontalAccuracy = maxHorizontalAccuracy
    }

    public static let approved = ProximityPolicy()
}

public enum ProximityResult: Equatable, Sendable {
    case withinRange(meters: Double)
    case tooFar(meters: Double)
    case fixTooOld
    case fixTooInaccurate
    case noFix
}

public enum Geodesy {
    public static func distanceInMeters(from: Coordinate, to: Coordinate) -> Double {
        let radius = 6_371_000.0
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return radius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    public static func evaluate(
        destination: Coordinate,
        fix: LocationFix?,
        now: Date,
        policy: ProximityPolicy = .approved
    ) -> ProximityResult {
        guard let fix else { return .noFix }
        guard now.timeIntervalSince(fix.timestamp) <= policy.maxFixAge else { return .fixTooOld }
        guard fix.horizontalAccuracy > 0, fix.horizontalAccuracy <= policy.maxHorizontalAccuracy else {
            return .fixTooInaccurate
        }
        let meters = distanceInMeters(from: fix.coordinate, to: destination)
        if meters <= policy.radiusMeters {
            return .withinRange(meters: meters)
        }
        return .tooFar(meters: meters)
    }
}

public enum PortuguesePlaceName {
    private static let particles: Set<String> = ["de", "do", "da", "dos", "das", "e"]

    public static func district(_ raw: String) -> String {
        let locale = Locale(identifier: "pt_PT")
        return raw.lowercased(with: locale)
            .split(whereSeparator: { $0.isWhitespace })
            .enumerated()
            .map { index, part in
                let word = String(part)
                if index > 0, particles.contains(word) { return word }
                return word.prefix(1).uppercased(with: locale) + word.dropFirst()
            }
            .joined(separator: " ")
    }
}

public enum PortugueseRelativeTime {
    public static func phrase(from date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 45 { return "há menos de 1 minuto" }
        if seconds < 90 { return "há 1 minuto" }
        if seconds < 3600 {
            return "há \(Int((seconds / 60).rounded())) minutos"
        }
        if seconds < 5400 { return "há 1 hora" }
        if seconds < 86_400 {
            return "há \(Int((seconds / 3600).rounded())) horas"
        }
        if seconds < 172_800 { return "há 1 dia" }
        return "há \(Int((seconds / 86_400).rounded())) dias"
    }

    public static func reportedPhrase(kind: CommunityIssueKind, from date: Date, now: Date) -> String {
        "\(kind.portugueseLabel) · reportado \(phrase(from: date, now: now))"
    }
}

/// Browsing may use a recent estimate; this policy never validates a report.
public enum MapLocationPolicy {
    public static func canDisplay(_ fix: LocationFix, at now: Date) -> Bool {
        let age = now.timeIntervalSince(fix.timestamp)
        return fix.coordinate.latitude.isFinite && fix.coordinate.longitude.isFinite
            && (-90...90).contains(fix.coordinate.latitude)
            && (-180...180).contains(fix.coordinate.longitude)
            && fix.horizontalAccuracy.isFinite && fix.horizontalAccuracy >= 0
            && age >= 0 && age <= 24 * 60 * 60
    }

    public static func widthKilometres(for fix: LocationFix) -> Double {
        // Use a wider initial view for estimates while keeping a portrait viewport
        // within the API area limit. The UI explicitly labels approximate fixes.
        max(3, min(6, fix.horizontalAccuracy * 2 / 1_000))
    }
}
