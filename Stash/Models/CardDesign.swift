import Foundation
import SwiftUI

/// Catégorie de style pour les designs de cartes intégrés (issus de CardArt).
enum CardDesignCategory: String, CaseIterable, Identifiable {
    case all
    case french
    case amex
    case apple
    case revolut
    case luxury
    case black
    case minimal
    case gradient
    case art

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:      return "Tous"
        case .french:   return "Banques FR"
        case .amex:     return "Amex"
        case .apple:    return "Apple"
        case .revolut:  return "Revolut"
        case .luxury:   return "Luxe"
        case .black:    return "Noir & Métal"
        case .minimal:  return "Minimaliste"
        case .gradient: return "Couleurs"
        case .art:      return "Art"
        }
    }

    var icon: String {
        switch self {
        case .all:      return "sparkles"
        case .french:   return "building.columns.fill"
        case .amex:     return "creditcard.fill"
        case .apple:    return "applelogo"
        case .revolut:  return "bolt.fill"
        case .luxury:   return "crown.fill"
        case .black:    return "shield.fill"
        case .minimal:  return "circle.grid.2x1.fill"
        case .gradient: return "paintpalette.fill"
        case .art:      return "paintbrush.pointed.fill"
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
        "CardDesigns/\(id)"
    }

    /// Récupère l'image SwiftUI correspondante.
    var image: Image {
        Image(assetName)
    }

    /// Catalogue complet des 29 designs intégrés dans l'app.
    static let allDesigns: [CardDesign] = [
        // MARK: - Banques Françaises
        CardDesign(
            id: "boursobank-official",
            name: "BoursoBank Officielle",
            category: .french,
            recommendedNetwork: .visa
        ),
        CardDesign(
            id: "boursobank-france",
            name: "BoursoBank Tricolore",
            category: .french,
            recommendedNetwork: .visa
        ),
        CardDesign(
            id: "bnp-premier",
            name: "BNP Paribas Premier",
            category: .french,
            recommendedNetwork: .visa
        ),
        CardDesign(
            id: "bnp-infinite",
            name: "BNP Paribas Infinite",
            category: .french,
            recommendedNetwork: .visa
        ),
        CardDesign(
            id: "bp-infinite",
            name: "Banque Populaire Infinite",
            category: .french,
            recommendedNetwork: .visa
        ),
        CardDesign(
            id: "visa-ca-infinite",
            name: "Crédit Agricole Infinite",
            category: .french,
            recommendedNetwork: .visa
        ),
        CardDesign(
            id: "visa-lcl-infinite",
            name: "LCL Infinite",
            category: .french,
            recommendedNetwork: .visa
        ),

        // MARK: - American Express
        CardDesign(
            id: "amex-gold",
            name: "American Express Gold",
            category: .amex,
            recommendedNetwork: .amex
        ),
        CardDesign(
            id: "amex-platinum",
            name: "American Express Platinum",
            category: .amex,
            recommendedNetwork: .amex
        ),
        CardDesign(
            id: "amex-centurion-black",
            name: "Centurion Noir",
            category: .amex,
            recommendedNetwork: .amex
        ),
        CardDesign(
            id: "amex-centurion-art",
            name: "Centurion Kehinde Wiley",
            category: .art,
            recommendedNetwork: .amex
        ),

        // MARK: - Apple
        CardDesign(
            id: "apple-card-white",
            name: "Apple Card Titane Blanc",
            category: .apple,
            recommendedNetwork: .mastercard
        ),
        CardDesign(
            id: "apple-black-visa",
            name: "Apple Card Noir Mat",
            category: .apple,
            recommendedNetwork: .visa
        ),
        CardDesign(
            id: "apple-liquid-glass",
            name: "Apple Liquid Glass",
            category: .gradient,
            recommendedNetwork: .unknown
        ),
        CardDesign(
            id: "apple-account",
            name: "Apple Account",
            category: .apple,
            recommendedNetwork: .unknown
        ),

        // MARK: - Revolut
        CardDesign(
            id: "revolut-metal-black",
            name: "Revolut Metal Black",
            category: .revolut,
            recommendedNetwork: .mastercard
        ),
        CardDesign(
            id: "revolut-black",
            name: "Revolut Noir Classique",
            category: .revolut,
            recommendedNetwork: .mastercard
        ),
        CardDesign(
            id: "revolut-prism",
            name: "Revolut Prisme",
            category: .gradient,
            recommendedNetwork: .mastercard
        ),

        // MARK: - International & Luxe
        CardDesign(
            id: "chase-sapphire",
            name: "Chase Sapphire Reserve",
            category: .luxury,
            recommendedNetwork: .visa
        ),
        CardDesign(
            id: "monzo-dark",
            name: "Monzo Dark",
            category: .minimal,
            recommendedNetwork: .mastercard
        ),
        CardDesign(
            id: "visa-coutts-silk",
            name: "Coutts Silk Soie",
            category: .luxury,
            recommendedNetwork: .visa
        ),

        // MARK: - Minimal & Métal
        CardDesign(
            id: "stealth-obsidian",
            name: "Obsidienne Stealth",
            category: .black,
            recommendedNetwork: .unknown
        ),
        CardDesign(
            id: "silver-titanium",
            name: "Titane Argent",
            category: .minimal,
            recommendedNetwork: .unknown
        ),
        CardDesign(
            id: "platinum-brushed",
            name: "Platine Brossé",
            category: .minimal,
            recommendedNetwork: .unknown
        ),

        // MARK: - Artistique & Dégradés
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
        )
    ]

    /// Recherche un design par son identifiant unique.
    static func find(_ id: String) -> CardDesign? {
        guard !id.isEmpty else { return nil }
        return allDesigns.first { $0.id == id }
    }

    /// Recommande les designs les plus pertinents selon le réseau et la banque détectée.
    static func recommended(network: CardNetwork, bankName: String) -> [CardDesign] {
        let bLower = bankName.lowercased()

        if bLower.contains("bourso") {
            return allDesigns.filter { $0.id.hasPrefix("boursobank") }
        }
        if bLower.contains("bnp") || bLower.contains("paribas") {
            return allDesigns.filter { $0.id.hasPrefix("bnp") }
        }
        if bLower.contains("populaire") {
            return allDesigns.filter { $0.id == "bp-infinite" }
        }
        if bLower.contains("agricole") {
            return allDesigns.filter { $0.id == "visa-ca-infinite" }
        }
        if bLower.contains("lcl") {
            return allDesigns.filter { $0.id == "visa-lcl-infinite" }
        }
        if bLower.contains("revolut") {
            return allDesigns.filter { $0.category == .revolut }
        }
        if bLower.contains("chase") {
            return allDesigns.filter { $0.id == "chase-sapphire" }
        }

        switch network {
        case .amex:
            return allDesigns.filter { $0.category == .amex || $0.recommendedNetwork == .amex }
        case .visa:
            return allDesigns.filter { $0.recommendedNetwork == .visa }
        case .mastercard:
            return allDesigns.filter { $0.recommendedNetwork == .mastercard || $0.category == .apple }
        default:
            return Array(allDesigns.prefix(6))
        }
    }
}
