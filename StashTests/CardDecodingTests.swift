import Testing
import Foundation
@testable import Stash

@Suite("Tests de décodage et compatibilité Card")
struct CardDecodingTests {

    @Test("Décodage d'un JSON de carte hérité (sans note, sans createdAt, sans hasCustomArt)")
    func testLegacyJsonDecoding() throws {
        let legacyJson = """
        {
            "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "kind": "loyalty",
            "name": "Fnac",
            "colorHex": "#D62836",
            "code": "1234567890128",
            "format": "ean13"
        }
        """

        let data = Data(legacyJson.utf8)
        let decoder = JSONDecoder()
        let card = try decoder.decode(Card.self, from: data)

        #expect(card.name == "Fnac")
        #expect(card.kind == .loyalty)
        #expect(card.code == "1234567890128")
        #expect(card.format == .ean13)
        #expect(card.note == "")
        #expect(card.hasCustomArt == false)
        #expect(card.bankName == "")
        #expect(card.manualNetworkRaw == "")
    }

    @Test("Réseau manuel vs réseau détecté")
    func testNetworkPriority() {
        var card = Card(kind: .bank, name: "Test")
        card.networkRaw = "visa"
        card.manualNetworkRaw = ""
        #expect(card.network == .visa)

        card.manualNetworkRaw = "mastercard"
        #expect(card.network == .mastercard)

        card.manualNetworkRaw = "unknown"
        #expect(card.network == .visa)
    }
}
