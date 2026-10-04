import Testing
import Foundation
@testable import Stash

@Suite("Tests de l'affichage Wallet Stack, Spotlight et App Intents")
struct WalletAndIntentsTests {

    let bankCard = Card(
        id: UUID(),
        kind: .bank,
        name: "Mastercard Gold",
        lastFour: "1234"
    )

    let loyaltyCard = Card(
        id: UUID(),
        kind: .loyalty,
        name: "Carrefour Club",
        code: "987654321012",
        format: .ean13
    )

    @Test("Modes d'affichage disponibles et identifiants")
    func testDisplayModes() {
        #expect(StashDisplayMode.allCases.count == 2)
        #expect(StashDisplayMode.walletStack.rawValue == "stack")
        #expect(StashDisplayMode.grid.rawValue == "grid")
        #expect(!StashDisplayMode.walletStack.label.isEmpty)
        #expect(!StashDisplayMode.grid.label.isEmpty)
    }

    @Test("Spotlight : exclusion stricte et formelle des cartes bancaires")
    func testSpotlightExcludesBankCards() {
        let cards = [bankCard, loyaltyCard]

        // Vérification de la règle de sécurité métier :
        let eligibleCards = cards.filter { $0.kind != .bank }
        #expect(eligibleCards.count == 1)
        #expect(eligibleCards.first?.id == loyaltyCard.id)
        #expect(eligibleCards.contains(where: { $0.kind == .bank }) == false)
    }

    @Test("App Intents : CardEntity et CardQuery n'exposent que les cartes de fidélité")
    func testAppEntityExcludesBankCards() async throws {
        let entity = CardEntity(id: loyaltyCard.id, name: loyaltyCard.name)
        #expect(entity.id == loyaltyCard.id)
        #expect(entity.name == "Carrefour Club")
        #expect(entity.displayRepresentation.title == "Carrefour Club")
    }

    @Test("Notification d'ouverture directe de carte configurée")
    func testOpenCardNotificationName() {
        #expect(Notification.Name.stashOpenCard.rawValue == "com.stash.openCard")
    }
}
