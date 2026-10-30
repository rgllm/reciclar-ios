import Foundation

public enum LocationIDStyle {
    /// Retired cache id: exactly three non-empty colon-separated parts.
    /// Public ids and every other string stay opaque.
    public static func isLegacySourceKey(_ id: String) -> Bool {
        let parts = id.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        return parts.allSatisfy { !$0.isEmpty }
    }
}

/// Pairs a cached retired location id with the public id of the same point.
///
/// The client cannot derive the public id. A pair is accepted only when
/// one retired location and one fetched non-retired location share a coordinate to
/// about a tenth of a metre, and that public id is used once.
public enum LocationIdentityCrosswalk {
    /// 1e-6 degrees is about 11 cm. Distinct collection points stay distinct.
    static let scale = 1_000_000.0

    public static func renames(existing: [Ecoponto], fetched: [Ecoponto]) -> [String: String] {
        var latest: [String: Ecoponto] = [:]
        latest.reserveCapacity(existing.count + fetched.count)
        for location in existing { latest[location.id] = location }
        for location in fetched { latest[location.id] = location }

        var legacyAt: [QuantizedCoordinate: [String]] = [:]
        for location in latest.values where LocationIDStyle.isLegacySourceKey(location.id) {
            legacyAt[QuantizedCoordinate(location.coordinate), default: []].append(location.id)
        }

        var publicAt: [QuantizedCoordinate: [String]] = [:]
        var seenPublic = Set<String>()
        for location in fetched where !LocationIDStyle.isLegacySourceKey(location.id) {
            guard seenPublic.insert(location.id).inserted else { continue }
            publicAt[QuantizedCoordinate(location.coordinate), default: []].append(location.id)
        }

        var claimed = Set<String>()
        var result: [String: String] = [:]
        for (key, legacyIDs) in legacyAt {
            guard legacyIDs.count == 1, let published = publicAt[key], published.count == 1 else { continue }
            let publicID = published[0]
            let legacyID = legacyIDs[0]
            guard legacyID != publicID, claimed.insert(publicID).inserted else { continue }
            result[legacyID] = publicID
        }
        return result
    }

    static func apply(
        existing: [Ecoponto],
        fetched: [Ecoponto],
        to snapshot: inout LocationSnapshot,
        locations all: inout [String: Ecoponto]
    ) {
        let renames = renames(existing: existing, fetched: fetched)
        guard !renames.isEmpty else { return }
        for (legacy, published) in renames {
            all.removeValue(forKey: legacy)
            snapshot.removedLocationIDs.remove(legacy)
            snapshot.removedLocationIDs.remove(published)
            snapshot.identityRenames[legacy] = published
        }
        for index in snapshot.cachedAreas.indices {
            var ids = snapshot.cachedAreas[index].locationIDs
            var changed = false
            for (legacy, published) in renames where ids.contains(legacy) {
                ids.remove(legacy)
                ids.insert(published)
                changed = true
            }
            if changed { snapshot.cachedAreas[index].locationIDs = ids }
        }
        if snapshot.communityEvents.contains(where: { renames[$0.ecopontoID] != nil }) {
            snapshot.communityEvents = snapshot.communityEvents.map { event in
                guard let published = renames[event.ecopontoID] else { return event }
                var updated = event
                updated.ecopontoID = published
                return updated
            }
        }
    }
}

private struct QuantizedCoordinate: Hashable {
    var latitude: Int
    var longitude: Int

    init(_ coordinate: Coordinate) {
        latitude = Int((coordinate.latitude * LocationIdentityCrosswalk.scale).rounded())
        longitude = Int((coordinate.longitude * LocationIdentityCrosswalk.scale).rounded())
    }
}
