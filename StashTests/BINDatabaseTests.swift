import Testing
import Foundation
@testable import Stash

@Suite("Tests de la base BIN / émetteurs bancaires")
struct BINDatabaseTests {

    @Test("Aucun préfixe dupliqué entre émetteurs")
    func testNoDuplicatePrefixes() {
        var seenPrefixes: [String: String] = [:] // Prefix -> Nom de banque
        for issuer in BINDatabase.issuers {
            for prefix in issuer.prefixes {
                if let existingBank = seenPrefixes[prefix] {
                    Issue.record("Le préfixe \(prefix) est en double entre '\(existingBank)' et '\(issuer.name)'")
                }
                seenPrefixes[prefix] = issuer.name
            }
        }
    }

    @Test("Résolution de banques françaises courantes")
    func testKnownIssuerResolution() {
        // Crédit Agricole (497103)
        let ca = BINDatabase.brandInfo(for: "4971030012345678")
        #expect(ca.bankName == "Crédit Agricole")
        #expect(ca.brandColors != nil)

        // BNP Paribas (497178)
        let bnp = BINDatabase.brandInfo(for: "4971780012345678")
        #expect(bnp.bankName == "BNP Paribas")

        // Société Générale (497201)
        let sg = BINDatabase.brandInfo(for: "4972010012345678")
        #expect(sg.bankName == "Société Générale")

        // Revolut (516830)
        let revolut = BINDatabase.brandInfo(for: "5168300012345678")
        #expect(revolut.bankName == "Revolut")
    }

    @Test("Numéro trop court ou inconnu")
    func testUnknownIssuerResolution() {
        // Moins de 6 chiffres
        let short = BINDatabase.brandInfo(for: "4971")
        #expect(short.bankName == nil)
        #expect(short.brandColors == nil)

        // Préfixe non répertorié
        let unknown = BINDatabase.brandInfo(for: "9999990012345678")
        #expect(unknown.bankName == nil)
        #expect(unknown.brandColors == nil)
    }
}
