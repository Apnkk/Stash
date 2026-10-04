import Testing
import Foundation
@testable import Stash

@Suite("Tests de validation de carte")
struct CardValidatorTests {

    @Test("Algorithme de Luhn sur numéros valides et invalides")
    func testLuhnAlgorithm() {
        // Valides classiques (Visa, Mastercard, Amex de test connus)
        #expect(CardValidator.passesLuhn("49927398716"))
        #expect(CardValidator.passesLuhn("49927398717") == false)
        #expect(CardValidator.passesLuhn("1234567812345670"))
        #expect(CardValidator.passesLuhn("1234567812345678") == false)

        // Moins de 2 chiffres -> false
        #expect(CardValidator.passesLuhn("4") == false)
        #expect(CardValidator.passesLuhn("") == false)
    }

    @Test("Validation de date d'expiration MM/AA")
    func testExpiryValidation() {
        // Format invalide
        #expect(CardValidator.isExpiryValid("") == false)
        #expect(CardValidator.isExpiryValid("13/28") == false)
        #expect(CardValidator.isExpiryValid("00/28") == false)
        #expect(CardValidator.isExpiryValid("12-28") == false)
        #expect(CardValidator.isExpiryValid("abc") == false)

        // Date passée
        #expect(CardValidator.isExpiryValid("01/20") == false)

        // Date future lointaine (valide)
        #expect(CardValidator.isExpiryValid("12/40"))

        // Mois courant
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let month = cal.component(.month, from: now)
        let year = cal.component(.year, from: now) % 100
        let currentMonthStr = String(format: "%02d/%02d", month, year)
        #expect(CardValidator.isExpiryValid(currentMonthStr))
    }

    @Test("Validation complète numéro (Luhn + longueur)")
    func testFullValidation() {
        // Numéro Visa 16 chiffres avec Luhn valide
        let validVisa = "49927398716" // 11 chiffres -> longueur invalide pour Visa standard
        let resultVisa = CardValidator.validate(validVisa)
        #expect(resultVisa.isLuhnValid == true)
        #expect(resultVisa.hasValidLength == false)
        #expect(resultVisa.isValid == false)
    }
}
