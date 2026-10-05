import Testing
import Foundation
@testable import Stash

@Suite("Tests du catalogue de designs de cartes")
struct CardDesignTests {

    @Test("Le catalogue contient exactement les 29 designs intégrés avec identifiants uniques")
    func testCatalogIntegrity() {
        let all = CardDesign.allDesigns
        #expect(all.count == 29)

        let ids = all.map(\.id)
        let uniqueIDs = Set(ids)
        #expect(ids.count == uniqueIDs.count)

        for design in all {
            #expect(!design.id.isEmpty)
            #expect(!design.name.isEmpty)
            #expect(design.assetName == "CardDesigns/\(design.id)")
        }
    }

    @Test("Recommandation intelligente de designs selon la banque et le réseau")
    func testRecommendations() {
        let boursoRecs = CardDesign.recommended(network: .visa, bankName: "BoursoBank")
        #expect(!boursoRecs.isEmpty)
        #expect(boursoRecs.contains { $0.id.hasPrefix("boursobank") })

        let amexRecs = CardDesign.recommended(network: .amex, bankName: "")
        #expect(!amexRecs.isEmpty)
        #expect(amexRecs.contains { $0.category == .amex })
    }

    @Test("Recherche de design par identifiant")
    func testFindDesign() {
        let centurion = CardDesign.find("amex-centurion-black")
        #expect(centurion != nil)
        #expect(centurion?.name == "Centurion Noir")
        #expect(centurion?.category == .amex)
        #expect(centurion?.recommendedNetwork == .amex)

        let unknown = CardDesign.find("design-inexistant")
        #expect(unknown == nil)
    }

    @Test("Codage et décodage du designID sur le modèle Card")
    func testCardDesignIDSerialization() throws {
        var card = Card(kind: .bank, name: "Ma carte prestige")
        card.designID = "apple-liquid-glass"

        let encoder = JSONEncoder()
        let data = try encoder.encode(card)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Card.self, from: data)

        #expect(decoded.designID == "apple-liquid-glass")
    }
}
