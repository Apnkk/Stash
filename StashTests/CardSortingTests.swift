import Testing
import Foundation
@testable import Stash

@Suite("Tests de tri et filtrage des cartes")
struct CardSortingTests {

    let cardA = Card(
        id: UUID(),
        kind: .bank,
        name: "BoursoBank",
        holder: "Alice",
        lastFour: "1111",
        bankName: "Boursorama",
        createdAt: Date(timeIntervalSince1970: 1000),
        isFavorite: false,
        lastUsedAt: Date(timeIntervalSince1970: 5000)
    )

    let cardB = Card(
        id: UUID(),
        kind: .loyalty,
        name: "Fnac",
        code: "FNAC123",
        createdAt: Date(timeIntervalSince1970: 2000),
        isFavorite: true,
        lastUsedAt: Date(timeIntervalSince1970: 3000)
    )

    let cardC = Card(
        id: UUID(),
        kind: .bank,
        name: "BNP Paribas",
        holder: "Bob",
        lastFour: "2222",
        bankName: "BNP",
        note: "Carte pro",
        createdAt: Date(timeIntervalSince1970: 3000),
        isFavorite: false,
        lastUsedAt: Date(timeIntervalSince1970: 1000)
    )

    @Test("Filtrage par type et favoris")
    func testFiltering() {
        let all = [cardA, cardB, cardC]

        let bankOnly = all.filtered(by: .bank)
        #expect(bankOnly.count == 2)
        #expect(bankOnly.allSatisfy { $0.kind == .bank })

        let loyaltyOnly = all.filtered(by: .loyalty)
        #expect(loyaltyOnly.count == 1)
        #expect(loyaltyOnly.first?.name == "Fnac")

        let favoritesOnly = all.filtered(by: .favorites)
        #expect(favoritesOnly.count == 1)
        #expect(favoritesOnly.first?.name == "Fnac")
    }

    @Test("Recherche textuelle multi-champs (nom, titulaire, note, 4 chiffres)")
    func testSearchQuery() {
        let all = [cardA, cardB, cardC]

        #expect(all.filtered(by: .all, query: "alice").count == 1)
        #expect(all.filtered(by: .all, query: "boursorama").count == 1)
        #expect(all.filtered(by: .all, query: "pro").count == 1)
        #expect(all.filtered(by: .all, query: "2222").count == 1)
        #expect(all.filtered(by: .all, query: "inconnu").isEmpty)
    }

    @Test("Tri alphabétique par nom avec et sans épinglage des favoris")
    func testSortByName() {
        let all = [cardA, cardB, cardC]

        // Avec épinglage : Fnac (favori) en tête, puis BNP Paribas, BoursoBank
        let withPin = all.sorted(by: .name, pinFavorites: true)
        #expect(withPin.map(\.name) == ["Fnac", "BNP Paribas", "BoursoBank"])

        // Sans épinglage : BNP Paribas, BoursoBank, Fnac
        let withoutPin = all.sorted(by: .name, pinFavorites: false)
        #expect(withoutPin.map(\.name) == ["BNP Paribas", "BoursoBank", "Fnac"])
    }

    @Test("Tri par date de dernière consultation (récent)")
    func testSortByRecent() {
        let all = [cardA, cardB, cardC]

        // BoursoBank (5000), Fnac (3000), BNP (1000)
        let sorted = all.sorted(by: .recent, pinFavorites: false)
        #expect(sorted.map(\.name) == ["BoursoBank", "Fnac", "BNP Paribas"])
    }
}
