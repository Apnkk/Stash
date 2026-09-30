import Foundation
import Combine

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

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("cards.json")
        load()
    }

    // MARK: - Chargement / sauvegarde

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            cards = try JSONDecoder().decode([Card].self, from: data)
        } catch {
            // Premier lancement ou fichier absent : liste vide, ce n'est pas une erreur.
            cards = []
        }
    }

    /// Écrit la liste sur disque. En cas d'échec, publie l'erreur pour l'UI.
    private func persist() {
        do {
            let data = try JSONEncoder().encode(cards)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            persistenceError = nil
        } catch {
            persistenceError = "Échec de l'enregistrement : \(error.localizedDescription)"
        }
    }

    // MARK: - Opérations

    /// Ajoute ou met à jour une carte. Pour une carte bancaire, `fullNumber`
    /// (le numéro complet) est stocké dans le Keychain, pas dans le JSON.
    /// - Throws: `SecureVault.VaultError` si l'écriture du secret échoue.
    func upsert(_ card: Card, fullNumber: String? = nil) throws {
        var toSave = card

        if card.kind == .bank, let number = fullNumber, !number.isEmpty {
            let digits = number.filter(\.isNumber)
            toSave.lastFour = String(digits.suffix(4))
            // On écrit d'abord le secret : si le Keychain refuse, on ne veut
            // pas laisser une carte sans son numéro. L'erreur remonte à l'UI.
            try SecureVault.save(digits, for: card.id.uuidString)
        }

        if let idx = cards.firstIndex(where: { $0.id == card.id }) {
            cards[idx] = toSave
        } else {
            cards.append(toSave)
            lastAddedCardID = toSave.id
        }
        persist()
    }

    /// Efface le marqueur de dernière carte ajoutée (après l'animation d'accueil).
    func clearLastAdded() {
        lastAddedCardID = nil
    }

    /// Supprime une carte et son éventuel secret dans le Keychain.
    /// La suppression du secret est non bloquante : la carte est retirée
    /// de la liste même si le Keychain renvoie une erreur.
    func delete(_ card: Card) {
        cards.removeAll { $0.id == card.id }
        if card.kind == .bank {
            _ = try? SecureVault.delete(card.id.uuidString)
        }
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
