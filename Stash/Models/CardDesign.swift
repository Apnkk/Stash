import Foundation
import SwiftUI

/// Catégorie de style pour les designs de cartes intégrés.
enum CardDesignCategory: String, CaseIterable, Identifiable {
    case all
    case black
    case luxury
    case gradient
    case minimal
    case art

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:      return "Tous"
        case .black:    return "Noir & Métal"
        case .luxury:   return "Luxe & Prestige"
        case .gradient: return "Couleurs"
        case .minimal:  return "Minimaliste"
        case .art:      return "Artistique"
        }
    }
}

/// Modèle d'un design de carte officiel intégré à Stash.
struct CardDesign: Identifiable, Hashable {
    let id: String
    let name: String
    let category: CardDesignCategory
    let recommendedNetwork: CardNetwork

    /// Nom de l'asset dans le catalogue Xcode Assets.
    var assetName: String {
        // Dans xcassets avec provides-namespace, le nom complet est CardDesigns/<id>
        "CardDesigns/\(id)"
    }

    /// Récupère l'image SwiftUI correspondante.
    var image: Image {
        Image(assetName)
    }

    /// Catalogue complet des 17 designs intégrés dans l'app.
    static let allDesigns: [CardDesign] = [
        CardDesign(
            id: "amex-centurion-black",
            name: "Centurion Noir",
            category: .black,
            recommendedNetwork: .amex
        ),
        CardDesign(
            id: "amex-centurion-art",
            name: "Centurion Kehinde Wiley",
            category: .art,
            recommendedNetwork: .amex
        ),
        CardDesign(
            id: "apple-black-visa",
            name: "Apple Noir Mat",
            category: .minimal,
            recommendedNetwork: .visa
        ),
        CardDesign(
            id: "apple-liquid-glass",
            name: "Liquid Glass",
            category: .gradient,
            recommendedNetwork: .unknown
        ),
        CardDesign(
            id: "silver-titanium",
            name: "Titane Argent",
            category: .minimal,
            recommendedNetwork: .unknown
        ),
        CardDesign(
            id: "stealth-obsidian",
            name: "Obsidienne Stealth",
            category: .black,
            recommendedNetwork: .unknown
        ),
        CardDesign(
            id: "platinum-brushed",
            name: "Platine Brossé",
            category: .minimal,
            recommendedNetwork: .unknown
        ),
        CardDesign(
            id: "rico-gold",
            name: "Picsou Or",
            category: .art,
            recommendedNetwork: .unknown
        ),
        CardDesign(
            id: "discover-orange",
            name: "Discover Flamme",
            category: .gradient,
            recommendedNetwork: .discover
        ),
        CardDesign(
            id: "discover-dawn",
            name: "Discover Aurore",
            category: .gradient,
            recommendedNetwork: .discover
        ),
        CardDesign(
            id: "discover-flag",
            name: "Discover USA Flag",
            category: .art,
            recommendedNetwork: .discover
        ),
        CardDesign(
            id: "discover-cashback",
            name: "Discover Chrome",
            category: .minimal,
            recommendedNetwork: .discover
        ),
        CardDesign(
            id: "revolut-black",
            name: "Revolut Noir",
            category: .black,
            recommendedNetwork: .mastercard
        ),
        CardDesign(
            id: "revolut-prism",
            name: "Revolut Prisme",
            category: .gradient,
            recommendedNetwork: .mastercard
        ),
        CardDesign(
            id: "visa-coutts-silk",
            name: "Coutts Silk Soie",
            category: .luxury,
            recommendedNetwork: .visa
        ),
        CardDesign(
            id: "visa-ca-infinite",
            name: "Crédit Agricole Infinite",
            category: .luxury,
            recommendedNetwork: .visa
        ),
        CardDesign(
            id: "visa-lcl-infinite",
            name: "LCL Infinite",
            category: .luxury,
            recommendedNetwork: .visa
        )
    ]

    /// Recherche un design par son identifiant.
    static func find(_ id: String) -> CardDesign? {
        allDesigns.first { $0.id == id }
    }
}
