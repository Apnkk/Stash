import Foundation

/// Options de tri pour la liste des cartes.
enum CardSortOption: String, CaseIterable, Identifiable {
    case manual
    case name
    case recent
    case dateAdded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual:    return "Ordre personnalisé"
        case .name:      return "Nom (A-Z)"
        case .recent:    return "Récemment consultées"
        case .dateAdded: return "Date d'ajout"
        }
    }

    var icon: String {
        switch self {
        case .manual:    return "arrow.up.arrow.down"
        case .name:      return "textformat.abc"
        case .recent:    return "clock"
        case .dateAdded: return "calendar"
        }
    }
}

/// Options de filtrage rapide (onglets / pastilles) au-dessus de la liste.
enum CardFilterOption: String, CaseIterable, Identifiable {
    case all
    case favorites
    case loyalty
    case bank
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:       return "Toutes"
        case .favorites: return "Favoris"
        case .loyalty:   return "Fidélité"
        case .bank:      return "Bancaire"
        case .other:     return "Autres"
        }
    }

    var icon: String {
        switch self {
        case .all:       return "square.grid.2x2"
        case .favorites: return "star.fill"
        case .loyalty:   return "barcode"
        case .bank:      return "creditcard"
        case .other:     return "tag"
        }
    }
}

extension Array where Element == Card {

    /// Filtre une liste de cartes selon le filtre actif et le texte de recherche.
    func filtered(by filter: CardFilterOption, query: String = "") -> [Card] {
        var list = self

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let q = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            list = list.filter { card in
                card.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(q)
                || card.holder.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(q)
                || card.bankName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(q)
                || card.note.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(q)
                || card.code.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(q)
                || card.lastFour.contains(q)
            }
        }

        switch filter {
        case .all:
            return list
        case .favorites:
            return list.filter(\.isFavorite)
        case .loyalty:
            return list.filter { $0.kind == .loyalty }
        case .bank:
            return list.filter { $0.kind == .bank }
        case .other:
            return list.filter { $0.kind == .other }
        }
    }

    /// Trie les cartes selon l'option choisie, avec placement prioritaire facultatif des favoris en tête.
    func sorted(by option: CardSortOption, pinFavorites: Bool = true) -> [Card] {
        let sortClosure: (Card, Card) -> Bool = { a, b in
            switch option {
            case .manual:
                return false
            case .name:
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .recent:
                let aDate = a.lastUsedAt ?? a.createdAt
                let bDate = b.lastUsedAt ?? b.createdAt
                return aDate > bDate
            case .dateAdded:
                return a.createdAt > b.createdAt
            }
        }

        if pinFavorites {
            let favs = self.filter(\.isFavorite)
            let others = self.filter { !$0.isFavorite }
            if option == .manual {
                return favs + others
            }
            return favs.sorted(by: sortClosure) + others.sorted(by: sortClosure)
        } else {
            if option == .manual {
                return self
            }
            return self.sorted(by: sortClosure)
        }
    }
}
