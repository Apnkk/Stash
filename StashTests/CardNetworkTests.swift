import Testing
import Foundation
@testable import Stash

@Suite("Tests de détection du réseau de carte")
struct CardNetworkTests {

    @Test("Détection réseau Visa")
    func testVisaDetection() {
        #expect(CardNetwork.detect(from: "4000 1234 5678 9010") == .visa)
        #expect(CardNetwork.detect(from: "4") == .visa)
    }

    @Test("Détection réseau Mastercard")
    func testMastercardDetection() {
        // Préfixe 51-55
        #expect(CardNetwork.detect(from: "5100 1234 5678 9010") == .mastercard)
        #expect(CardNetwork.detect(from: "5500 0000 0000 0000") == .mastercard)
        // Plage 2221-2720
        #expect(CardNetwork.detect(from: "2221 0000 0000 0000") == .mastercard)
        #expect(CardNetwork.detect(from: "2720 9999 9999 9999") == .mastercard)
    }

    @Test("Détection réseau American Express")
    func testAmexDetection() {
        #expect(CardNetwork.detect(from: "3400 123456 78901") == .amex)
        #expect(CardNetwork.detect(from: "3700 123456 78901") == .amex)
    }

    @Test("Détection réseau Discover")
    func testDiscoverDetection() {
        #expect(CardNetwork.detect(from: "6500 1234 5678 9010") == .discover)
        #expect(CardNetwork.detect(from: "6011 0000 0000 0000") == .discover)
    }

    @Test("Réseau inconnu")
    func testUnknownDetection() {
        #expect(CardNetwork.detect(from: "") == .unknown)
        #expect(CardNetwork.detect(from: "9999") == .unknown)
    }

    @Test("Règles de groupement et longueurs valides")
    func testNetworkRules() {
        #expect(CardNetwork.amex.validLengths == [15])
        #expect(CardNetwork.amex.groupSizes == [4, 6, 5])
        #expect(CardNetwork.visa.validLengths.contains(16))
        #expect(CardNetwork.mastercard.validLengths == [16])
    }
}
