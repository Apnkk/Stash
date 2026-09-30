import Foundation
import Security

/// Coffre chiffré adossé au Keychain iOS.
///
/// On y stocke les données sensibles (numéros de carte bancaire complets)
/// séparément des métadonnées visibles. Les entrées sont protégées par
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` : accessibles seulement
/// quand l'appareil est déverrouillé, jamais sauvegardées ni transférées
/// vers un autre appareil.
enum SecureVault {

    private static let service = "app.stash.securevault"

    /// Enregistre (ou remplace) un secret pour une clé donnée.
    @discardableResult
    static func save(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Supprime l'éventuelle valeur existante avant de réécrire.
        delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Lit un secret. Renvoie `nil` s'il n'existe pas.
    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    /// Supprime le secret associé à une clé.
    @discardableResult
    static func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
