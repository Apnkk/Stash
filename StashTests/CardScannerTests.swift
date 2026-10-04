import Testing
import Foundation
import Vision
@testable import Stash

@Suite("Tests du scanner et reconnaissance OCR")
struct CardScannerTests {

    @Test("Extraction de carte bancaire valide depuis du texte OCR")
    func testExtractBankCardInfoValid() {
        // Numéro Visa valide (Luhn) : 4532 0150 1234 5670 (somme = 50)
        let lines = [
            "CREDIT AGRICOLE",
            "4532 0150 1234 5670",
            "EXPIRES 08/29",
            "JEAN DUPONT"
        ]

        let result = CardScanner.extractBankCardInfo(from: lines)
        #expect(result != nil)
        #expect(result?.number == "4532015012345670")
        #expect(result?.expiry == "08/29")
    }

    @Test("Rejet des numéros ne passant pas l'algorithme de Luhn")
    func testExtractBankCardInfoInvalidLuhn() {
        // Numéro altéré avec mauvais dernier chiffre (somme = 57)
        let lines = [
            "BANQUE",
            "4532 0150 1234 5677",
            "08/29"
        ]

        let result = CardScanner.extractBankCardInfo(from: lines)
        #expect(result == nil)
    }

    @Test("Extraction avec séparateurs variés de date d'expiration")
    func testExtractExpirySeparators() {
        let linesSlash = ["4532015012345670", "VALID THRU 12/28"]
        #expect(CardScanner.extractBankCardInfo(from: linesSlash)?.expiry == "12/28")

        let linesDash = ["4532015012345670", "12-28"]
        #expect(CardScanner.extractBankCardInfo(from: linesDash)?.expiry == "12/28")

        let linesDot = ["4532015012345670", "12.28"]
        #expect(CardScanner.extractBankCardInfo(from: linesDot)?.expiry == "12/28")
    }

    @Test("Mappage des formats de codes-barres Vision vers Stash")
    func testSymbologyMapping() {
        #expect(CardScanner.mapSymbology(.qr) == .qr)
        #expect(CardScanner.mapSymbology(.ean13) == .ean13)
        #expect(CardScanner.mapSymbology(.ean8) == .ean8)
        #expect(CardScanner.mapSymbology(.code128) == .code128)
        #expect(CardScanner.mapSymbology(.pdf417) == .pdf417)
        #expect(CardScanner.mapSymbology(.aztec) == .aztec)
    }
}
