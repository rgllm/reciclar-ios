import CoreLocation
import ReciclarCore
import Foundation

@MainActor
@Observable
final class UserLocationService: NSObject {
    var authorization: CLAuthorizationStatus
    var lastFix: LocationFix?
    private(set) var displayFix: LocationFix?
    var permissionExplanation = "Podes pesquisar lugares sem localização. Para usar a tua posição ou confirmar que estás junto de um ecoponto, autoriza a localização enquanto usas a app."
    private let manager = CLLocationManager()
    private var authorizationWaiters: [CheckedContinuation<Void, Never>] = []
    private var fixWaiters: [CheckedContinuation<LocationFix?, Never>] = []
    private var fixTimeout: Task<Void, Never>?
    private var authorizationTimeout: Task<Void, Never>?

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    var showsUserLocation: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }
    var reportAccess: ReportLocationAccess {
        if isDenied { return .denied }
        if showsUserLocation { return .authorized }
        return .notDetermined
    }

    func prepareForDisplay() async -> Bool {
        await requestAccessIfNeeded()
        guard showsUserLocation else { return false }
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        if let fix = await requestFix() {
            displayFix = fix
            return true
        }
        guard showsUserLocation else { return false }
        // A cached Core Location estimate is for browsing only. Resolving an
        // issue still requires a new fix and proximity validation.
        let cached = manager.location.map {
            LocationFix(coordinate: Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude),
                        horizontalAccuracy: $0.horizontalAccuracy, timestamp: $0.timestamp)
        }
        displayFix = [cached, lastFix, displayFix].compactMap { $0 }
            .filter { MapLocationPolicy.canDisplay($0, at: Date()) }
            .max { $0.timestamp < $1.timestamp }
        return displayFix != nil
    }
    func prepareForProximityCheck() async -> Bool {
        await requestAccessIfNeeded()
        guard showsUserLocation else { return false }
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        return await requestFix(force: true) != nil
    }
    fileprivate func applyAuthorization(_ status: CLAuthorizationStatus) {
        authorization = status
        if status != .notDetermined {
            authorizationTimeout?.cancel()
            let waiters = authorizationWaiters; authorizationWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
        if !showsUserLocation { manager.stopUpdatingLocation(); resolveWaiters(nil); lastFix = nil; displayFix = nil }
    }
    fileprivate func applyLocation(_ location: CLLocation) {
        guard CLLocationCoordinate2DIsValid(location.coordinate), location.horizontalAccuracy.isFinite,
              location.horizontalAccuracy >= 0,
              Date().timeIntervalSince(location.timestamp) >= 0,
              Date().timeIntervalSince(location.timestamp) < 30 else { resolveWaiters(nil); return }
        let fix = LocationFix(coordinate: Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
                              horizontalAccuracy: location.horizontalAccuracy, timestamp: location.timestamp)
        lastFix = fix
        resolveWaiters(fix)
    }
    fileprivate func failFix() { resolveWaiters(nil) }
    private func requestAccessIfNeeded() async {
        guard authorization == .notDetermined else { return }
        await withCheckedContinuation { continuation in
            authorizationWaiters.append(continuation)
            if authorizationWaiters.count == 1 {
                manager.requestWhenInUseAuthorization()
                authorizationTimeout = Task {
                    do { try await Task.sleep(for: .seconds(60)) } catch { return }
                    let waiters = authorizationWaiters; authorizationWaiters.removeAll()
                    waiters.forEach { $0.resume() }
                }
            }
        }
    }
    private func requestFix(force: Bool = false) async -> LocationFix? {
        if !force, let lastFix, (0..<30).contains(Date().timeIntervalSince(lastFix.timestamp)) { return lastFix }
        return await withCheckedContinuation { continuation in
            fixWaiters.append(continuation)
            if fixWaiters.count == 1 {
                manager.requestLocation()
                fixTimeout = Task {
                    do { try await Task.sleep(for: .seconds(8)) } catch { return }
                    resolveWaiters(nil)
                }
            }
        }
    }
    private func resolveWaiters(_ fix: LocationFix?) {
        fixTimeout?.cancel()
        manager.stopUpdatingLocation()
        let waiters = fixWaiters; fixWaiters.removeAll()
        waiters.forEach { $0.resume(returning: fix) }
    }
}

extension UserLocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.applyAuthorization(status) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.applyLocation(location) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.failFix() }
    }
}
