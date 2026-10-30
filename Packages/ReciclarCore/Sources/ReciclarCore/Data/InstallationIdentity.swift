import Foundation
#if canImport(Security)
import Security
#endif

/// Removes the installation identifier written by builds that sent a stable id.
/// Current builds do not create a replacement. Calling this on every launch is
/// idempotent and also clears a value restored from a backup.
public enum LegacyInstallationIdentity {
    public static let keychainService = "pt.ecopontos.app"
    public static let keychainAccount = "installation-id"
    /// Keys a previous build may have used. The map viewport is not in this list.
    public static let userDefaultsKeys = ["installation-id", "installationId", "installation_id"]

    public static func deletePersistedValues(userDefaults: UserDefaults = .standard) {
        for key in userDefaultsKeys {
            userDefaults.removeObject(forKey: key)
        }
        deleteKeychainItem()
    }

    public static func deleteKeychainItem() {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
        #endif
    }
}
