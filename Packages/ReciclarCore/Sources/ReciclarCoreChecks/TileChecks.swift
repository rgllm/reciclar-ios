import Foundation
import ReciclarCore

func runTileChecks() -> [String] {
    var failures: [String] = []
    func check(_ value: Bool, _ message: String) { if !value { failures.append(message) } }

    check(MapTilePolicy.zoom == 11, "viewport tiles use the fixed z")
    let lisbon = Coordinate(latitude: 38.7223, longitude: -9.1393)
    let tile = SlippyMapTiles.tile(containing: lisbon, zoom: MapTilePolicy.zoom)
    check(tile == SlippyTileCoordinate(z: 11, x: 972, y: 784), "Lisbon falls in tile 11/972/784")
    let bounds = tile.bounds
    check(bounds.contains(lisbon), "tile bounds contain the point that selected the tile")
    check(abs(bounds.minLongitude - -9.140625) < 1e-9, "tile west edge")
    check(abs(bounds.maxLongitude - -8.96484375) < 1e-9, "tile east edge")
    check(abs(bounds.minLatitude - 38.685509760012) < 1e-6, "tile south edge")
    check(abs(bounds.maxLatitude - 38.82259097617711) < 1e-6, "tile north edge")

    let braga = Coordinate(latitude: 41.55, longitude: -8.4)
    let bragaTile = SlippyMapTiles.tile(containing: braga, zoom: 11)
    check(bragaTile == SlippyTileCoordinate(z: 11, x: 976, y: 763), "Braga sample point tile")
    let viewport = GeographicBounds(center: braga, latitudeDelta: 0.03, longitudeDelta: 0.03)
    let covering = try? SlippyMapTiles.covering(viewport, zoom: MapTilePolicy.zoom)
    check(covering == [bragaTile], "a small viewport is one tile")
    if let covering {
        let union = covering.map(\.bounds)
        check(union.allSatisfy { $0.isValid }, "covering tiles have valid bounds")
        check(union.contains { $0.contains(braga) }, "covering tiles contain the viewport center")
    }

    let wide = GeographicBounds(
        minLatitude: 41.55 - (24 / 111.32) / 2,
        maxLatitude: 41.55 + (24 / 111.32) / 2,
        minLongitude: -8.4 - (24 / (111.32 * cos(41.55 * .pi / 180))) / 2,
        maxLongitude: -8.4 + (24 / (111.32 * cos(41.55 * .pi / 180))) / 2
    )
    if let wideTiles = try? SlippyMapTiles.covering(wide, zoom: MapTilePolicy.zoom) {
        check(wideTiles.count <= 9, "24 km viewport touches at most 9 tiles")
        check(wideTiles.count == 9, "24 km viewport at Braga's latitude covers 9 tiles")
        check(Set(wideTiles).count == wideTiles.count, "covering tiles are unique")
    } else {
        failures.append("24 km viewport should resolve to tiles")
    }

    check(RefreshBackoff.delay(step: 0, retryAfter: nil) == 30, "backoff starts at 30 s")
    check(RefreshBackoff.delay(step: 1, retryAfter: nil) == 60, "backoff doubles")
    check(RefreshBackoff.delay(step: 2, retryAfter: nil) == 120, "backoff step 2")
    check(RefreshBackoff.delay(step: 3, retryAfter: nil) == 240, "backoff step 3")
    check(RefreshBackoff.delay(step: 4, retryAfter: nil) == 300, "backoff caps at 5 min")
    check(RefreshBackoff.delay(step: 5, retryAfter: nil) == 300, "backoff stays capped")
    check(RefreshBackoff.delay(step: 0, retryAfter: 90) == 90, "Retry-After longer than the step wins")
    check(RefreshBackoff.delay(step: 0, retryAfter: 10) == 30, "Retry-After shorter than the floor stays at 30 s")
    return failures
}
