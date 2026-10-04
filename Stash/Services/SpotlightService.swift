import Foundation
import CoreSpotlight
import MobileCoreServices
import UniformTypeIdentifiers

/// Service d'indexation Spotlight locale.
///
/// Respecte scrupuleusement la confidentialité des données :
/// - Les cartes bancaires ne sont JAMAIS indexées dans Spotlight sous aucun prétexte.
/// - Seules les cartes de fidélité dont l'utilisateur a explicitement autorisé
///   l'indexation dans les Réglages peuvent apparaître dans la recherche iOS.
enum SpotlightService {

    static let settingsKey = "spotlight_indexing_enabled"

    /// L'indexation Spotlight est-elle activée par l'utilisateur ?
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: settingsKey) }
        set { UserDefaults.standard.set(newValue, forKey: settingsKey) }
    }

    /// Met à jour l'index Spotlight avec les cartes éligibles.
    static func updateIndex(with cards: [Card]) {
        guard isEnabled else {
            deindexAll()
            return
        }

        // STRICT : Seules les cartes NON bancaires sont indexées.
        let eligibleCards = cards.filter { $0.kind != .bank }

        let items: [CSSearchableItem] = eligibleCards.map { card in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
            attributeSet.title = card.name
            attributeSet.contentDescription = "Carte de fidélité Stash • \(card.code)"
            attributeSet.keywords = [card.name, "carte", "fidelite", "stash", card.code]

            return CSSearchableItem(
                uniqueIdentifier: card.id.uuidString,
                domainIdentifier: "com.stash.loyalty",
                attributeSet: attributeSet
            )
        }

        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.stash.loyalty"]) { _ in
            if !items.isEmpty {
                CSSearchableIndex.default().indexSearchableItems(items) { error in
                    if let error {
                        print("Erreur indexation Spotlight: \(error)")
                    }
                }
            }
        }
    }

    /// Supprime tous les éléments Stash de l'index Spotlight.
    static func deindexAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.stash.loyalty"])
    }
}
