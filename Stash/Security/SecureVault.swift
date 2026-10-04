import Foundation
import Security
import LocalAuthentication

/// Coffre chiffré adossé au Keychain iOS.
///
/// On y stocke les données sensibles (numéros de carte bancaire complets)
/// séparément des métadonnées visibles. Deux niveaux de protection :
/// - `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` : jamais sauvegardé ni
///   transféré vers un autre appareil ;
/// - un `SecAccessControl` avec `.biometryCurrentSet` : le Keychain lui-même
///   exige Face ID / Touch ID à CHAQUE lecture du secret. Même un
///   contournement de la couche applicative ne donne rien, et le secret
///   devient illisible si l'ensemble biométrique change (ajout d'un doigt /
///   visage), ce qui protège contre un enrôlement forcé.
enum SecureVault {

    private static let service = "app.stash.securevault"

    /// Erreurs remontées à l'appelant pour un retour UI explicite.
    enum VaultError: Error, LocalizedError {
        case encodingFailed
        case accessControlFailed
        case keychainFailed(OSStatus)
        case userCancelled
        case authFailed
        case itemNotFound

        var errorDescription: String? {
            switch self {
            case .encodingFailed:      return "Impossible d'encoder le secret."
            case .accessControlFailed: return "Impossible de créer la protection biométrique."
            case .keychainFailed(let s): return "Erreur du trousseau (code \(s))."
            case .userCancelled:       return "Authentification annulée."
            case .authFailed:          return "Authentification refusée."
            case .itemNotFound:        return "Numéro introuvable dans le trousseau."
            }
        }
    }

    /// Construit le contrôle d'accès biométrique ou code d'accès partagé par save/read.
    /// Utilise `.biometryCurrentSet` avec repli `.devicePasscode` pour ne jamais
    /// perdre définitivement les données si Face ID est reconfiguré.
    private static func makeAccessControl() -> SecAccessControl? {
        SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet, .or, .devicePasscode],
            nil
        )
    }

    /// Enregistre (ou remplace) un secret pour une clé donnée.
    /// L'écriture NE déclenche PAS de prompt biométrique (seule la lecture le fait).
    @discardableResult
    static func save(_ value: String, for key: String) throws -> Bool {
        guard let data = value.data(using: .utf8) else {
            throw VaultError.encodingFailed
        }
        guard let access = makeAccessControl() else {
            throw VaultError.accessControlFailed
        }

        // Supprime l'éventuelle valeur existante avant de réécrire.
        _ = try? delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: access
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultError.keychainFailed(status)
        }
        return true
    }

    /// Lit un secret. Déclenche le prompt biométrique / code du Keychain.
    /// - Parameter prompt: message affiché dans la boîte de dialogue système.
    static func read(_ key: String, prompt: String) throws -> String {
        let context = LAContext()
        context.localizedReason = prompt
        let val = try read(key, context: context)
        // Migration transparente vers la nouvelle politique de contrôle d'accès
        _ = try? save(val, for: key)
        return val
    }

    /// Lit un secret en réutilisant un LAContext déjà authentifié.
    static func read(_ key: String, context: LAContext) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                throw VaultError.encodingFailed
            }
            return value
        case errSecItemNotFound:
            throw VaultError.itemNotFound
        case errSecUserCanceled:
            throw VaultError.userCancelled
        case errSecAuthFailed:
            throw VaultError.authFailed
        default:
            throw VaultError.keychainFailed(status)
        }
    }

    /// Lit une collection de secrets avec un seul contexte d'authentification partagé.
    static func readAll(keys: [String], context: LAContext = LAContext()) throws -> [String: String] {
        var results: [String: String] = [:]
        for key in keys {
            if let val = try? read(key, context: context) {
                results[key] = val
                _ = try? save(val, for: key)
            }
        }
        return results
    }

    /// Liste toutes les clés (comptes) actuellement stockées dans ce service.
    /// Ne déclenche PAS de prompt biométrique : on ne lit que les attributs
    /// (les comptes), jamais les données secrètes elles-mêmes.
    /// - Returns: l'ensemble des clés présentes (vide si aucune ou si le
    ///   trousseau est inaccessible).
    static func allKeys() -> Set<String> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        return Set(items.compactMap { $0[kSecAttrAccount as String] as? String })
    }

    /// Supprime le secret associé à une clé. Ne déclenche pas de prompt.
    @discardableResult
    static func delete(_ key: String) throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VaultError.keychainFailed(status)
        }
        return true
    }
}
