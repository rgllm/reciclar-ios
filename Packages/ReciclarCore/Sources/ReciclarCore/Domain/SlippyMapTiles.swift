import Foundation

/// Fixed slippy-map zoom for viewports up to 24 km.
/// The API accepts only this z and returns 400 for every other value.
/// At mainland Portugal a z=11 tile is about 14.5–16 km wide, so a 24 km viewport touches at most 9 tiles.
public enum MapTilePolicy {
    public static let zoom = 11
    public static let freshness: TimeInterval = 15 * 60
    public static let maximumTilesPerViewport = 9
    public static let favouriteBatchLimit = 50
    public static let backoffMinimum: TimeInterval = 30
    public static let backoffMaximum: TimeInterval = 5 * 60
}

public enum RefreshBackoff {
    /// Exponential delay from 30 s to 5 min. A `Retry-After` longer than that step wins.
    public static func delay(step: Int, retryAfter: TimeInterval?) -> TimeInterval {
        let exponent = Double(max(0, step))
        let exponential = min(MapTilePolicy.backoffMaximum, MapTilePolicy.backoffMinimum * pow(2, exponent))
        return max(exponential, retryAfter ?? 0)
    }
}

public struct SlippyTileCoordinate: Hashable, Sendable, Codable {
    public var z: Int
    public var x: Int
    public var y: Int

    public init(z: Int, x: Int, y: Int) {
        self.z = z
        self.x = x
        self.y = y
    }

    public var cacheKey: String { "\(z)/\(x)/\(y)" }

    public var bounds: GeographicBounds { SlippyMapTiles.bounds(for: self) }
}

public enum SlippyMapTiles {
    public static let maximumLatitude = 85.05112878

    public static func tile(containing coordinate: Coordinate, zoom: Int) -> SlippyTileCoordinate {
        let clampedZoom = min(max(zoom, 0), 28)
        let limit = (1 << clampedZoom) - 1
        let n = Double(1 << clampedZoom)
        let latitude = min(max(coordinate.latitude, -maximumLatitude), maximumLatitude)
        let longitude = min(max(coordinate.longitude, -180), 180)
        var x = Int(floor((longitude + 180) / 360 * n))
        let latitudeRadians = latitude * .pi / 180
        let mercator = log(tan(latitudeRadians) + 1 / cos(latitudeRadians))
        var y = Int(floor((1 - mercator / .pi) / 2 * n))
        x = min(max(x, 0), limit)
        y = min(max(y, 0), limit)
        return SlippyTileCoordinate(z: clampedZoom, x: x, y: y)
    }

    public static func bounds(for tile: SlippyTileCoordinate) -> GeographicBounds {
        let n = Double(1 << tile.z)
        let west = Double(tile.x) / n * 360 - 180
        let east = Double(tile.x + 1) / n * 360 - 180
        return GeographicBounds(
            minLatitude: latitude(forMercatorY: tile.y + 1, n: n),
            maxLatitude: latitude(forMercatorY: tile.y, n: n),
            minLongitude: west,
            maxLongitude: east
        )
    }

    public static func covering(_ bounds: GeographicBounds, zoom: Int) throws -> [SlippyTileCoordinate] {
        guard bounds.isValid, (0...22).contains(zoom) else { throw ReciclarAPIError.invalidResponse }
        let northwest = tile(containing: Coordinate(latitude: bounds.maxLatitude, longitude: bounds.minLongitude), zoom: zoom)
        let southeast = tile(containing: Coordinate(latitude: bounds.minLatitude, longitude: bounds.maxLongitude), zoom: zoom)
        guard northwest.x <= southeast.x, northwest.y <= southeast.y else { throw ReciclarAPIError.invalidResponse }
        var tiles: [SlippyTileCoordinate] = []
        tiles.reserveCapacity((southeast.x - northwest.x + 1) * (southeast.y - northwest.y + 1))
        for x in northwest.x...southeast.x {
            for y in northwest.y...southeast.y {
                tiles.append(SlippyTileCoordinate(z: zoom, x: x, y: y))
            }
        }
        guard !tiles.isEmpty, tiles.count <= MapTilePolicy.maximumTilesPerViewport else {
            throw ReciclarAPIError.invalidResponse
        }
        return tiles
    }

    private static func latitude(forMercatorY y: Int, n: Double) -> Double {
        let mercator = .pi * (1 - 2 * Double(y) / n)
        return atan(sinh(mercator)) * 180 / .pi
    }
}
