import Foundation
import AppIntents

/// Entité App Intents représentant une carte de fidélité dans Siri et Raccourcis.
/// Les cartes bancaires sont strictement exclues par confidentialité.
struct CardEntity: AppEntity {
    static var defaultQuery = CardQuery()

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Carte Stash"

    var id: UUID

    @Property(title: "Nom")
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

/// Requête d'entités pour retrouver ou suggérer des cartes à Siri et aux Raccourcis.
struct CardQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [CardEntity] {
        let store = CardStore()
        return store.cards
            .filter { $0.kind != .bank && identifiers.contains($0.id) }
            .map { CardEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [CardEntity] {
        let store = CardStore()
        return store.cards
            .filter { $0.kind != .bank }
            .map { CardEntity(id: $0.id, name: $0.name) }
    }
}

/// Intention d'ouverture directe d'une carte (Action button, Siri, Raccourcis).
struct OpenCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Ouvrir une carte"
    static var description = IntentDescription("Ouvre directement une carte de fidélité dans Stash.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Carte")
    var card: CardEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .stashOpenCard,
            object: nil,
            userInfo: ["cardID": card.id]
        )
        return .result()
    }
}

/// Déclaration des raccourcis automatiques disponibles dans l'application Raccourcis et Siri.
struct StashShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenCardIntent(),
            phrases: [
                "Ouvre \(\.$card) dans \(.applicationName)",
                "Afficher \(\.$card) dans \(.applicationName)"
            ],
            shortTitle: "Ouvrir une carte",
            systemImageName: "creditcard.fill"
        )
    }
}

extension Notification.Name {
    static let stashOpenCard = Notification.Name("com.stash.openCard")
}
