import Foundation
import SwiftUI

/// Type de carte géré par l'app.
enum CardKind: String, Codable, CaseIterable, Identifiable {
    case loyalty      // carte de fidélité (code-barres / QR)
    case bank         // carte bancaire (stockée chiffrée, consultation seule)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .loyalty: return "Fidélité"
        case .bank:    return "Bancaire"
        }
    }
}

/// Format de code affiché pour une carte de fidélité.
enum BarcodeFormat: String, Codable, CaseIterable, Identifiable {
    case auto
    case code128
    case ean13
    case qr

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto:    return "Automatique"
        case .code128: return "Code-barres (CODE128)"
        case .ean13:   return "Code-barres (EAN-13)"
        case .qr:      return "QR Code"
        }
    }
}

/// Modèle unique pour les deux types de cartes.
/// Les champs sensibles (numéro de CB) ne sont JAMAIS stockés en clair :
/// ils vivent dans le Keychain via `SecureVault`, indexés par `id`.
struct Card: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: CardKind
    var name: String
    var colorHex: String

    // --- Fidélité ---
    var code: String                 // valeur du code-barres / QR
    var format: BarcodeFormat

    // --- Bancaire (métadonnées non secrètes) ---
    var holder: String               // titulaire
    var expiry: String               // MM/AA
    var lastFour: String             // 4 derniers chiffres, affichés masqués

    init(
        id: UUID = UUID(),
        kind: CardKind,
        name: String,
        colorHex: String = "#4C8DFF",
        code: String = "",
        format: BarcodeFormat = .auto,
        holder: String = "",
        expiry: String = "",
        lastFour: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.colorHex = colorHex
        self.code = code
        self.format = format
        self.holder = holder
        self.expiry = expiry
        self.lastFour = lastFour
    }
}

/// Palette de couleurs proposée à l'ajout d'une carte.
enum Palette {
    static let colors: [String] = [
        "#4C8DFF", "#FF5A5F", "#34C759", "#FF9F0A",
        "#AF52DE", "#00C7BE", "#FF375F", "#5E5CE6",
        "#8E8E93", "#1C1C1E"
    ]
}

extension Color {
    /// Crée une `Color` à partir d'une chaîne hexadécimale (#RRGGBB).
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8) / 255.0
            b = Double(value & 0x0000FF) / 255.0
        } else {
            r = 0.3; g = 0.55; b = 1.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
