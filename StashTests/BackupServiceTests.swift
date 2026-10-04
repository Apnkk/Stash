import Testing
import Foundation
@testable import Stash

@Suite("Tests de sauvegarde chiffrée AES-256-GCM")
struct BackupServiceTests {

    let sampleCard = Card(
        id: UUID(),
        kind: .bank,
        name: "Carte Secrète",
        lastFour: "9999"
    )

    @Test("Chiffrement et déchiffrement réussi avec mot de passe")
    func testEncryptAndDecrypt() throws {
        let cards = [sampleCard]
        let secrets = [sampleCard.id.uuidString: "4532015012345670"]
        let password = "MotDePasseSuperSecurise2026!"

        let archive = try BackupService.exportEncryptedBackup(
            cards: cards,
            secrets: secrets,
            password: password
        )

        #expect(archive.count > 34)
        #expect(archive.prefix(6) == BackupService.magicHeader)

        let restored = try BackupService.importEncryptedBackup(
            archiveData: archive,
            password: password
        )

        #expect(restored.version == 2)
        #expect(restored.cards.count == 1)
        #expect(restored.cards.first?.id == sampleCard.id)
        #expect(restored.secrets[sampleCard.id.uuidString] == "4532015012345670")
    }

    @Test("Échec du déchiffrement avec mauvais mot de passe")
    func testWrongPasswordFails() throws {
        let cards = [sampleCard]
        let secrets = [sampleCard.id.uuidString: "4532015012345670"]
        let password = "BonMotDePasse123"

        let archive = try BackupService.exportEncryptedBackup(
            cards: cards,
            secrets: secrets,
            password: password
        )

        #expect(throws: BackupService.BackupError.self) {
            _ = try BackupService.importEncryptedBackup(
                archiveData: archive,
                password: "MauvaisMotDePasse456"
            )
        }
    }

    @Test("Rejet des fichiers avec en-tête magique invalide")
    func testInvalidHeaderRejection() {
        let fakeData = Data("FICHIER_INVALIDE_NON_STASH_DONNEES".utf8)
        #expect(throws: BackupService.BackupError.self) {
            _ = try BackupService.importEncryptedBackup(
                archiveData: fakeData,
                password: "test"
            )
        }
    }

    @Test("Refus des mots de passe vides")
    func testEmptyPasswordRejection() {
        #expect(throws: BackupService.BackupError.self) {
            _ = try BackupService.exportEncryptedBackup(
                cards: [],
                secrets: [:],
                password: ""
            )
        }
    }

    @Test("CardStore export et import d'archive chiffrée")
    @MainActor
    func testCardStoreEncryptedBackupRoundtrip() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StashBackupTest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("cards.json")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = CardStore(fileURL: fileURL)
        let loyalty = Card(kind: .loyalty, name: "Fnac", code: "123456")
        try store.upsert(loyalty)

        let password = "TestPassword987!"
        let backupData = try store.exportEncryptedBackup(password: password)

        let store2 = CardStore(fileURL: tempDir.appendingPathComponent("cards2.json"))
        let importedCount = try store2.importEncryptedBackup(backupData, password: password)

        #expect(importedCount == 1)
        #expect(store2.cards.first?.name == "Fnac")
        #expect(store2.cards.first?.code == "123456")
    }
}
