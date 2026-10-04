import Foundation
import Combine
import UIKit
import LocalAuthentication

/// Source de vérité de l'app : la liste des cartes.
///
/// - Les métadonnées (nom, couleur, code fidélité, 4 derniers chiffres…)
///   sont sérialisées en JSON dans le dossier Documents.
/// - Le numéro complet d'une carte bancaire n'est JAMAIS écrit ici :
///   il vit dans `SecureVault` (Keychain), indexé par l'id de la carte.
@MainActor
final class CardStore: ObservableObject {

    @Published private(set) var cards: [Card] = []

    /// Dernière erreur de persistance, à afficher dans l'UI (nil si tout va bien).
    @Published var persistenceError: String?

    /// Id de la dernière carte AJOUTÉE (pas modifiée), pour la surligner
    /// brièvement à l'accueil. Remise à `nil` une fois l'animation jouée.
    @Published var lastAddedCardID: UUID?

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let customURL = fileURL {
            self.fileURL = customURL
        } else {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.fileURL = dir.appendingPathComponent("cards.json")
        }
        load()
    }

    // MARK: - Chargement / sauvegarde

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // Premier lancement : fichier absent, liste vide normale.
            cards = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            cards = try JSONDecoder().decode([Card].self, from: data)
            persistenceError = nil
        } catch {
            // Fichier présent mais illisible ou corrompu : on NE doit PAS l'écraser.
            // On le met en quarantaine pour préserver les données de l'utilisateur.
            quarantineCorruptFile()
            cards = []
            persistenceError = "Le fichier de cartes était corrompu ou illisible. Une copie de sécurité a été créée."
        }
    }

    /// Déplace un fichier corrompu vers un nom horodaté pour éviter toute perte irrémédiable.
    private func quarantineCorruptFile() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let corruptURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("cards.corrupt-\(timestamp).json")
        try? FileManager.default.moveItem(at: fileURL, to: corruptURL)
    }

    /// Écrit la liste sur disque. En cas d'échec, publie l'erreur pour l'UI.
    private func persist() {
        do {
            let data = try JSONEncoder().encode(cards)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            persistenceError = nil
            AutoBackupService.performAutoBackup(cards: cards)
        } catch {
            persistenceError = "Échec de l'enregistrement : \(error.localizedDescription)"
        }
    }

    // MARK: - Opérations

    /// Décrit l'intention de l'utilisateur vis-à-vis de l'image de fond lors
    /// d'un `upsert`, pour ne pas confondre « ne rien changer » et « retirer ».
    enum ArtChange {
        case unchanged          // laisser l'image existante telle quelle
        case set(UIImage)       // définir / remplacer par cette image
        case remove             // retirer l'image existante
    }

    /// Ajoute ou met à jour une carte. Pour une carte bancaire, `fullNumber`
    /// (le numéro complet) est stocké dans le Keychain, pas dans le JSON.
    /// L'image de fond éventuelle est écrite via `ArtVault`, indexée par id.
    /// - Throws: `SecureVault.VaultError` si l'écriture du secret échoue,
    ///           ou `ArtVault.ArtError` si l'écriture de l'image échoue.
    func upsert(_ card: Card, fullNumber: String? = nil, art: ArtChange = .unchanged) throws {
        var toSave = card

        if card.kind == .bank, let number = fullNumber, !number.isEmpty {
            let digits = number.filter(\.isNumber)
            toSave.lastFour = String(digits.suffix(4))
            // On écrit d'abord le secret : si le Keychain refuse, on ne veut
            // pas laisser une carte sans son numéro. L'erreur remonte à l'UI.
            try SecureVault.save(digits, for: card.id.uuidString)
        }

        // Gestion de l'image de fond. On écrit/supprime le fichier AVANT de
        // fixer le drapeau, pour que `hasCustomArt` reflète l'état réel du disque.
        switch art {
        case .unchanged:
            // On conserve le drapeau tel qu'il vient (ou l'état existant si la
            // carte existe déjà et que l'appelant ne l'a pas touché).
            if let existing = cards.first(where: { $0.id == card.id }) {
                toSave.hasCustomArt = existing.hasCustomArt
            }
        case .set(let image):
            try ArtVault.save(image, for: card.id.uuidString)
            toSave.hasCustomArt = true
        case .remove:
            ArtVault.delete(card.id.uuidString)
            toSave.hasCustomArt = false
        }

        if let idx = cards.firstIndex(where: { $0.id == card.id }) {
            cards[idx] = toSave
        } else {
            cards.append(toSave)
            lastAddedCardID = toSave.id
        }
        persist()
        ExpiryReminderService.scheduleReminders(for: toSave)
    }

    /// Efface le marqueur de dernière carte ajoutée (après l'animation d'accueil).
    func clearLastAdded() {
        lastAddedCardID = nil
    }

    /// Bascule l'état favori d'une carte et persiste le changement.
    func toggleFavorite(_ card: Card) {
        guard let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[idx].isFavorite.toggle()
        persist()
    }

    /// Enregistre la consultation / utilisation récente de la carte.
    func markUsed(_ card: Card) {
        guard let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[idx].lastUsedAt = Date()
        persist()
    }

    /// Supprime une carte et son éventuel secret dans le Keychain.
    /// La suppression du secret est non bloquante : la carte est retirée
    /// de la liste même si le Keychain renvoie une erreur.
    func delete(_ card: Card) {
        cards.removeAll { $0.id == card.id }
        if card.kind == .bank {
            _ = try? SecureVault.delete(card.id.uuidString)
        }
        ArtVault.delete(card.id.uuidString)
        ExpiryReminderService.cancelReminders(for: card.id)
        persist()
    }

    /// Lit le numéro complet d'une carte bancaire. La lecture déclenche le
    /// prompt Face ID / Touch ID du Keychain lui-même.
    /// - Parameter reason: message affiché dans la boîte de dialogue système.
    /// - Throws: `SecureVault.VaultError` (annulation, refus, absence…).
    func fullNumber(for card: Card, reason: String) throws -> String {
        try SecureVault.read(card.id.uuidString, prompt: reason)
    }

    /// Réordonne les cartes (drag & drop dans la liste) et persiste le nouvel ordre.
    func move(from source: IndexSet, to destination: Int) {
        cards.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    /// Supprime des cartes par leurs positions (swipe dans la liste).
    func delete(at offsets: IndexSet) {
        for index in offsets {
            let card = cards[index]
            if card.kind == .bank {
                _ = try? SecureVault.delete(card.id.uuidString)
            }
            ArtVault.delete(card.id.uuidString)
            ExpiryReminderService.cancelReminders(for: card.id)
        }
        cards.remove(atOffsets: offsets)
        persist()
    }

    // MARK: - Export / import (sauvegarde des métadonnées, JAMAIS les secrets)

    /// Exporte les cartes en JSON. Les numéros de CB (Keychain) ne sont
    /// PAS inclus : seules les métadonnées visibles sont sauvegardées.
    func exportData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(cards)
    }

    /// Importe des cartes depuis un JSON exporté. Fusionne par `id`
    /// (remplace une carte existante, ajoute les nouvelles). Chaque carte est
    /// validée avant d'être acceptée : une carte incohérente (nom vide, date
    /// d'expiration invalide) est ignorée plutôt qu'injectée telle quelle.
    /// - Returns: le nombre de cartes réellement importées, ou `nil` si le
    ///   format global du fichier est invalide (rien n'a pu être décodé).
    @discardableResult
    func importData(_ data: Data) -> Int? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let imported = try? decoder.decode([Card].self, from: data) else {
            return nil
        }

        var accepted = 0
        for card in imported where isImportable(card) {
            if let idx = cards.firstIndex(where: { $0.id == card.id }) {
                cards[idx] = card
            } else {
                cards.append(card)
            }
            accepted += 1
        }
        persist()
        purgeOrphanSecrets()
        return accepted
    }

    /// Supprime du Keychain les secrets (numéros de CB) qui n'ont plus de carte
    /// correspondante dans la liste. Utile après un import ou une suppression
    /// dont l'effacement du secret aurait échoué silencieusement. Ne touche
    /// jamais les secrets encore rattachés à une carte existante.
    func purgeOrphanSecrets() {
        let liveIDs = Set(cards.map { $0.id.uuidString })
        for key in SecureVault.allKeys() where !liveIDs.contains(key) {
            _ = try? SecureVault.delete(key)
        }
        // Même logique pour les images de fond orphelines (import/suppression).
    }

    // MARK: - Sauvegarde complète chiffrée par mot de passe (.stashbackup)

    /// Exporte une archive chiffrée par mot de passe contenant les cartes et les secrets Keychain.
    func exportEncryptedBackup(password: String, context: LAContext = LAContext()) throws -> Data {
        let bankCardKeys = cards.filter { $0.kind == .bank }.map { $0.id.uuidString }
        let secrets = bankCardKeys.isEmpty ? [:] : ((try? SecureVault.readAll(keys: bankCardKeys, context: context)) ?? [:])
        return try BackupService.exportEncryptedBackup(cards: cards, secrets: secrets, password: password)
    }

    /// Restaure une archive chiffrée par mot de passe et réinjecte les secrets dans le Keychain.
    @discardableResult
    func importEncryptedBackup(_ data: Data, password: String) throws -> Int {
        let payload = try BackupService.importEncryptedBackup(archiveData: data, password: password)

        var accepted = 0
        for card in payload.cards where isImportable(card) {
            if let idx = cards.firstIndex(where: { $0.id == card.id }) {
                cards[idx] = card
            } else {
                cards.append(card)
            }
            if let secret = payload.secrets[card.id.uuidString], !secret.isEmpty {
                _ = try? SecureVault.save(secret, for: card.id.uuidString)
            }
            accepted += 1
        }
        persist()
        return accepted
    }

    /// Contrôle de cohérence minimal d'une carte reçue par import, pour ne pas
    /// laisser entrer de données bancales dans le store.
    private func isImportable(_ card: Card) -> Bool {
        // Un nom non vide est indispensable pour l'affichage.
        guard !card.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        // Si une date d'expiration est renseignée, elle doit être parsable
        // (on n'exige pas qu'elle soit future : une carte expirée reste
        // légitimement archivable par l'utilisateur).
        if card.kind == .bank, !card.expiry.isEmpty {
            let parts = card.expiry.split(separator: "/")
            guard parts.count == 2,
                  let month = Int(parts[0]), (1...12).contains(month),
                  Int(parts[1]) != nil else {
                return false
            }
        }
        return true
    }
}
