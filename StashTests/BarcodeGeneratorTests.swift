import Testing
import Foundation
import UIKit
@testable import Stash

@Suite("Tests de génération de code-barres")
struct BarcodeGeneratorTests {

    @Test("Résolution automatique du format de code")
    func testResolvedFormat() {
        // EAN-13 avec clé de contrôle exacte (ex: 4006381333931)
        var card = Card(kind: .loyalty, name: "Test EAN13")
        card.format = .auto
        card.code = "4006381333931"
        #expect(BarcodeGenerator.resolvedFormat(for: card) == .ean13)

        // 13 chiffres avec clé erronée : doit basculer sur code128 pour ne pas modifier la valeur
        card.code = "4006381333930" // Mauvaise clé
        #expect(BarcodeGenerator.resolvedFormat(for: card) == .code128)

        // 12 chiffres : complété par EAN-13
        card.code = "400638133393"
        #expect(BarcodeGenerator.resolvedFormat(for: card) == .ean13)

        // Alphanumérique court (jusqu'à 48 car) : code128
        card.code = "CARTE-CLIENT-99"
        #expect(BarcodeGenerator.resolvedFormat(for: card) == .code128)

        // Texte plus complexe ou long : QR code
        card.code = "https://stash.local/card/detail/123456789"
        #expect(BarcodeGenerator.resolvedFormat(for: card) == .qr)
    }

    @Test("Génération EAN-13 : refus formel des clés invalides")
    func testEan13InvalidChecksumRejection() {
        var card = Card(kind: .loyalty, name: "Test")
        card.format = .ean13

        // Clé valide
        card.code = "4006381333931"
        #expect(BarcodeGenerator.image(for: card) != nil)

        // Clé invalide imposée en EAN-13 -> l'app doit refuser et renvoyer nil plutôt que fabriquer un mauvais code
        card.code = "4006381333930"
        #expect(BarcodeGenerator.image(for: card) == nil)
    }

    @Test("Génération QR code et Code 128")
    func testQrAndCode128Generation() {
        var card = Card(kind: .loyalty, name: "Test")

        card.format = .qr
        card.code = "STASH-LOYALTY"
        #expect(BarcodeGenerator.image(for: card) != nil)

        card.format = .code128
        card.code = "123456789"
        #expect(BarcodeGenerator.image(for: card) != nil)
    }

    @Test("Génération EAN-8 et UPC-A avec contrôle de clé")
    func testEan8AndUpca() {
        var card = Card(kind: .loyalty, name: "Test")

        // EAN-8 valide
        card.format = .ean8
        card.code = "96385074"
        #expect(BarcodeGenerator.image(for: card) != nil)

        // EAN-8 7 chiffres (complété automatiquement)
        card.code = "9638507"
        #expect(BarcodeGenerator.image(for: card) != nil)

        // EAN-8 clé invalide
        card.code = "96385070"
        #expect(BarcodeGenerator.image(for: card) == nil)

        // UPC-A valide
        card.format = .upca
        card.code = "012345678905"
        #expect(BarcodeGenerator.image(for: card) != nil)

        // UPC-A 11 chiffres (complété automatiquement)
        card.code = "01234567890"
        #expect(BarcodeGenerator.image(for: card) != nil)

        // UPC-A clé invalide
        card.code = "012345678901"
        #expect(BarcodeGenerator.image(for: card) == nil)
    }

    @Test("Génération PDF417 et Aztec")
    func testPdf417AndAztec() {
        var card = Card(kind: .loyalty, name: "Test")

        card.format = .pdf417
        card.code = "BOARDING-PASS-STASH-12345"
        #expect(BarcodeGenerator.image(for: card) != nil)

        card.format = .aztec
        card.code = "AZTEC-STASH-TICKET"
        #expect(BarcodeGenerator.image(for: card) != nil)
    }
}
