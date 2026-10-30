import Foundation

public struct GeographicBounds: Sendable, Hashable, Codable {
    public var minLatitude: Double
    public var maxLatitude: Double
    public var minLongitude: Double
    public var maxLongitude: Double

    public init(minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
    }

    public init(center: Coordinate, latitudeDelta: Double, longitudeDelta: Double, paddingFraction: Double = 0.2) {
        let paddedLat = max(latitudeDelta * (1 + paddingFraction), 0.002)
        let paddedLon = max(longitudeDelta * (1 + paddingFraction), 0.002)
        minLatitude = center.latitude - paddedLat / 2
        maxLatitude = center.latitude + paddedLat / 2
        minLongitude = center.longitude - paddedLon / 2
        maxLongitude = center.longitude + paddedLon / 2
    }

    public var isValid: Bool {
        [minLatitude, maxLatitude, minLongitude, maxLongitude].allSatisfy(\.isFinite)
            && minLatitude >= -85 && maxLatitude <= 85 && minLongitude >= -180 && maxLongitude <= 180
            && minLatitude < maxLatitude && minLongitude < maxLongitude
    }

    public var maximumDimensionKilometres: Double {
        max((maxLatitude - minLatitude) * 111.32,
            (maxLongitude - minLongitude) * 111.32 * cos((minLatitude + maxLatitude) / 2 * .pi / 180))
    }

    public func contains(_ other: GeographicBounds) -> Bool {
        minLatitude <= other.minLatitude && maxLatitude >= other.maxLatitude
            && minLongitude <= other.minLongitude && maxLongitude >= other.maxLongitude
    }

    public var queryValue: String {
        [minLongitude, minLatitude, maxLongitude, maxLatitude].map { String($0) }.joined(separator: ",")
    }

    public func contains(_ coordinate: Coordinate) -> Bool {
        (minLatitude...maxLatitude).contains(coordinate.latitude)
            && (minLongitude...maxLongitude).contains(coordinate.longitude)
    }
}

public struct SpatialIndex: Sendable {
    public private(set) var locations: [Ecoponto] = []
    private var byID: [String: Int] = [:]
    private var cells: [Int: [Int]] = [:]
    private let cellSize = 0.04

    public init() {}

    public init(locations: [Ecoponto]) {
        rebuild(locations)
    }

    public mutating func rebuild(_ locations: [Ecoponto]) {
        self.locations = locations
        byID.removeAll(keepingCapacity: true)
        cells.removeAll(keepingCapacity: true)
        byID.reserveCapacity(locations.count)
        for (index, location) in locations.enumerated() {
            byID[location.id] = index
            cells[cellKey(location.coordinate), default: []].append(index)
        }
    }

    public func location(id: String) -> Ecoponto? {
        guard let index = byID[id] else { return nil }
        return locations[index]
    }

    public func locations(in bounds: GeographicBounds) -> [Ecoponto] {
        if bounds.maximumDimensionKilometres > 24.1 { return locations.filter { bounds.contains($0.coordinate) } }
        var seen = Set<Int>()
        var result: [Ecoponto] = []
        var latitude = bounds.minLatitude
        while latitude <= bounds.maxLatitude + cellSize {
            var longitude = bounds.minLongitude
            while longitude <= bounds.maxLongitude + cellSize {
                if let indices = cells[cellKey(Coordinate(latitude: latitude, longitude: longitude))] {
                    for index in indices where seen.insert(index).inserted {
                        let location = locations[index]
                        if bounds.contains(location.coordinate) {
                            result.append(location)
                        }
                    }
                }
                longitude += cellSize
            }
            latitude += cellSize
        }
        return result
    }

    private func cellKey(_ coordinate: Coordinate) -> Int {
        let x = Int(((coordinate.latitude + 90) / cellSize).rounded(.down))
        let y = Int(((coordinate.longitude + 180) / cellSize).rounded(.down))
        return x * 100_000 + y
    }
}

public enum MapPresentationItem: Identifiable, Hashable, Sendable {
    case pin(Ecoponto)
    case cluster(id: String, coordinate: Coordinate, count: Int)

    public var id: String {
        switch self {
        case .pin(let location): "pin:\(location.id)"
        case .cluster(let id, _, _): "cluster:\(id)"
        }
    }

    public var coordinate: Coordinate {
        switch self {
        case .pin(let location): location.coordinate
        case .cluster(_, let coordinate, _): coordinate
        }
    }
}

public enum MapPresentationPolicy {
    public static let maximumPins = 500
    public static let clusterWhenLatitudeSpanExceeds = 0.22

    public static func items(
        from locations: [Ecoponto],
        in bounds: GeographicBounds,
        latitudeSpan: Double,
        filter: LocationFilter,
        now: Date
    ) -> [MapPresentationItem] {
        let matching = locations.filter { bounds.contains($0.coordinate) && filter.matches($0, at: now) }
        if matching.isEmpty { return [] }

        if latitudeSpan >= clusterWhenLatitudeSpanExceeds || matching.count > maximumPins {
            return clusters(from: matching, latitudeSpan: latitudeSpan)
        }
        return matching.map { .pin($0) }
    }

    public static func listLocations(
        from locations: [Ecoponto],
        in bounds: GeographicBounds,
        filter: LocationFilter,
        now: Date,
        limit: Int = 200
    ) -> [Ecoponto] {
        var result: [Ecoponto] = []
        result.reserveCapacity(min(limit, locations.count))
        for location in locations {
            guard bounds.contains(location.coordinate), filter.matches(location, at: now) else { continue }
            result.append(location)
            if result.count == limit { break }
        }
        return result.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private static func clusters(from locations: [Ecoponto], latitudeSpan: Double) -> [MapPresentationItem] {
        let cell = max(pow(2, ceil(log2(max(latitudeSpan, 0.001) / 7 / 0.015))) * 0.015, 0.015)
        var buckets: [Int: (sumLat: Double, sumLon: Double, members: [Ecoponto])] = [:]
        for location in locations {
            let key = clusterKey(location.coordinate, cell: cell)
            var bucket = buckets[key] ?? (0, 0, [])
            bucket.sumLat += location.coordinate.latitude
            bucket.sumLon += location.coordinate.longitude
            bucket.members.append(location)
            buckets[key] = bucket
        }

        return buckets.sorted { $0.key < $1.key }.map { key, bucket in
            if bucket.members.count == 1, let location = bucket.members.first {
                return .pin(location)
            }
            return .cluster(
                id: String(key),
                coordinate: Coordinate(
                    latitude: bucket.sumLat / Double(bucket.members.count),
                    longitude: bucket.sumLon / Double(bucket.members.count)
                ),
                count: bucket.members.count
            )
        }
    }

    private static func clusterKey(_ coordinate: Coordinate, cell: Double) -> Int {
        let x = Int(((coordinate.latitude + 90) / cell).rounded(.down))
        let y = Int(((coordinate.longitude + 180) / cell).rounded(.down))
        return x * 100_000 + y
    }
}

/// What the map should say when the visible area has no pins.
/// A successful load with zero ecopontos is `noCoverage`. A failed download is `failed`.
public enum MapLoadPresentation: Equatable, Sendable {
    case zoomIn
    case loading
    case failed
    case notCached
    case noCoverage
    case noMatches
    case locations
}

public enum MapLoadPresentationPolicy {
    public static func presentation(
        needsZoom: Bool,
        visibleLocationCount: Int,
        isLoading: Bool,
        refreshFailed: Bool,
        areaLoaded: Bool,
        filtersActive: Bool
    ) -> MapLoadPresentation {
        if needsZoom { return .zoomIn }
        if visibleLocationCount > 0 { return .locations }
        if isLoading { return .loading }
        if refreshFailed { return .failed }
        if !areaLoaded { return .notCached }
        if filtersActive { return .noMatches }
        return .noCoverage
    }
}
