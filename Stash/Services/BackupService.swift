import Foundation
import CryptoKit
import CommonCrypto

/// Service de sauvegarde complète, hautement sécurisée, chiffrée de bout en bout
/// par mot de passe utilisateur via AES-256-GCM et dérivation de clé PBKDF2.
///
/// Contrairement aux exports JSON en clair, ce format (`.stashbackup`) contient
/// TOUTES les données : métadonnées des cartes ET numéros secrets complets du trousseau.
enum BackupService {

    /// En-tête magique identifiant le fichier d'archive Stash v2.
    static let magicHeader = "STASH2".data(using: .utf8)!
    static let saltLength = 16
    static let pbkdf2Rounds: UInt32 = 600_000
    static let keyLength = 32 // 256 bits

    enum BackupError: LocalizedError {
        case invalidMagic
        case fileTooShort
        case keyDerivationFailed
        case decryptionFailed
        case serializationFailed
        case emptyPassword

        var errorDescription: String? {
            switch self {
            case .invalidMagic:
                return "Le fichier sélectionné n'est pas une archive de sauvegarde Stash valide."
            case .fileTooShort:
                return "Le fichier de sauvegarde est corrompu ou incomplet."
            case .keyDerivationFailed:
                return "Échec de génération de la clé de déchiffrement."
            case .decryptionFailed:
                return "Mot de passe incorrect ou sauvegarde altérée."
            case .serializationFailed:
                return "Échec de préparation des données de sauvegarde."
            case .emptyPassword:
                return "Le mot de passe de sauvegarde ne peut pas être vide."
            }
        }
    }

    /// Contenu complet de l'archive avant chiffrement.
    struct BackupPayload: Codable {
        var version: Int
        var exportDate: Date
        var cards: [Card]
        /// Dictionnaire [cardID.uuidString: fullNumber] des secrets extraits du Keychain
        var secrets: [String: String]
    }

    // MARK: - Dérivation de clé PBKDF2 (CommonCrypto)

    /// Dérive une clé symétrique 256 bits à partir du mot de passe et d'un sel aléatoire
    /// en appliquant 600 000 itérations HMAC-SHA256 (recommandation OWASP 2024+).
    static func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        guard !password.isEmpty else { throw BackupError.emptyPassword }
        guard let passData = password.data(using: .utf8) else { throw BackupError.keyDerivationFailed }

        var derivedBytes = Data(count: keyLength)
        let status = derivedBytes.withUnsafeMutableBytes { derivedBuf in
            salt.withUnsafeBytes { saltBuf in
                passData.withUnsafeBytes { passBuf in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passBuf.baseAddress?.assumingMemoryBound(to: CChar.self),
                        passData.count,
                        saltBuf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        pbkdf2Rounds,
                        derivedBuf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else { throw BackupError.keyDerivationFailed }
        return SymmetricKey(data: derivedBytes)
    }

    // MARK: - Export chiffré

    /// Construit l'archive binaire chiffrée avec le mot de passe spécifié.
    static func exportEncryptedBackup(
        cards: [Card],
        secrets: [String: String],
        password: String
    ) throws -> Data {
        let payload = BackupPayload(
            version: 2,
            exportDate: Date(),
            cards: cards,
            secrets: secrets
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let plaintext = try? encoder.encode(payload) else {
            throw BackupError.serializationFailed
        }

        // 1. Génération d'un sel aléatoire de 16 octets
        var salt = Data(count: saltLength)
        let saltResult = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, saltLength, $0.baseAddress!)
        }
        guard saltResult == errSecSuccess else { throw BackupError.keyDerivationFailed }

        // 2. Dérivation de clé AES-256
        let symmetricKey = try deriveKey(password: password, salt: salt)

        // 3. Chiffrement AES-256-GCM (nonce 12 octets généré par CryptoKit, tag 16 octets inclus)
        let sealedBox = try AES.GCM.seal(plaintext, using: symmetricKey)
        guard let combinedCiphertext = sealedBox.combined else {
            throw BackupError.serializationFailed
        }

        // 4. Concaténation : [Magic 6B] + [Salt 16B] + [Combined AES-GCM (nonce + ciphertext + tag)]
        var finalArchive = Data()
        finalArchive.append(magicHeader)
        finalArchive.append(salt)
        finalArchive.append(combinedCiphertext)

        return finalArchive
    }

    // MARK: - Import et déchiffrement

    /// Valide, déchiffre et extrait le contenu d'une archive `.stashbackup`.
    static func importEncryptedBackup(
        archiveData: Data,
        password: String
    ) throws -> BackupPayload {
        let headerSize = magicHeader.count + saltLength
        guard archiveData.count > headerSize + 28 else { // nonce 12 + min ciphertext + tag 16
            throw BackupError.fileTooShort
        }

        // 1. Vérification de l'en-tête magique
        let fileMagic = archiveData.prefix(magicHeader.count)
        guard fileMagic == magicHeader else {
            throw BackupError.invalidMagic
        }

        // 2. Extraction du sel
        let salt = archiveData.subdata(in: magicHeader.count..<headerSize)

        // 3. Dérivation de la clé
        let symmetricKey = try deriveKey(password: password, salt: salt)

        // 4. Déchiffrement AES-256-GCM
        let combinedCiphertext = archiveData.subdata(in: headerSize..<archiveData.count)
        let sealedBox = try AES.GCM.SealedBox(combined: combinedCiphertext)
        guard let decryptedData = try? AES.GCM.open(sealedBox, using: symmetricKey) else {
            throw BackupError.decryptionFailed
        }

        // 5. Décodage du payload JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(BackupPayload.self, from: decryptedData) else {
            throw BackupError.serializationFailed
        }

        return payload
    }
}
