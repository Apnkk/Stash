import Testing
import Foundation
@testable import Stash

@Suite("Tests de persistance et résilience de CardStore")
@MainActor
struct CardStoreTests {

    private func createTempStore() -> (CardStore, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StashTest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("cards.json")
        let store = CardStore(fileURL: fileURL)
        return (store, fileURL)
    }

    @Test("Sauvegarde et rechargement d'une carte")
    @MainActor
    func testSaveAndReload() throws {
        let (store, fileURL) = createTempStore()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let card = Card(kind: .loyalty, name: "Supermarché", code: "987654321")
        try store.upsert(card)

        #expect(store.cards.count == 1)
        #expect(store.cards.first?.name == "Supermarché")
        #expect(store.persistenceError == nil)

        // Recharge depuis un nouveau store pointant sur le même fichier
        let store2 = CardStore(fileURL: fileURL)
        #expect(store2.cards.count == 1)
        #expect(store2.cards.first?.code == "987654321")
    }

    @Test("Quarantaine et protection contre la perte de données sur fichier corrompu")
    @MainActor
    func testCorruptFileQuarantine() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StashTest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("cards.json")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Écrit des données corrompues (non-JSON)
        let corruptData = Data("DONNEES_CORROMPUES_NON_JSON".utf8)
        try corruptData.write(to: fileURL)

        // Initialisation de CardStore avec ce fichier
        let store = CardStore(fileURL: fileURL)

        // Doit signaler l'erreur sans crasher
        #expect(store.cards.isEmpty)
        #expect(store.persistenceError != nil)

        // Vérifie qu'un fichier de quarantaine a été créé avec le contenu intact
        let dirContents = (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path)) ?? []
        let quarantineFiles = dirContents.filter { $0.contains("cards.corrupt-") }
        #expect(quarantineFiles.count == 1)

        if let quarantineName = quarantineFiles.first {
            let quarantineURL = tempDir.appendingPathComponent(quarantineName)
            let preserved = try? Data(contentsOf: quarantineURL)
            #expect(preserved == corruptData)
        }
    }

    @Test("Exportation et importation de cartes")
    @MainActor
    func testExportAndImport() throws {
        let (store1, file1) = createTempStore()
        let (store2, file2) = createTempStore()
        defer {
            try? FileManager.default.removeItem(at: file1.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: file2.deletingLastPathComponent())
        }

        let card1 = Card(kind: .loyalty, name: "Carte 1", code: "111")
        let card2 = Card(kind: .other, name: "Badge Entrée", code: "BADGE-42")
        try store1.upsert(card1)
        try store1.upsert(card2)

        guard let exportData = store1.exportData() else {
            Issue.record("Échec d'exportation des données")
            return
        }

        let count = store2.importData(exportData)
        #expect(count == 2)
        #expect(store2.cards.count == 2)
        #expect(store2.cards.contains(where: { $0.name == "Badge Entrée" }))
    }
}
