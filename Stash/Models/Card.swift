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

/// Réseau d'une carte bancaire, déduit du préfixe du numéro (règles IIN simplifiées).
enum CardNetwork: String, Codable {
    case visa
    case mastercard
    case amex
    case discover
    case unknown

    var label: String {
        switch self {
        case .visa:       return "Visa"
        case .mastercard: return "Mastercard"
        case .amex:       return "American Express"
        case .discover:   return "Discover"
        case .unknown:    return "Carte"
        }
    }

    /// Détecte le réseau à partir du numéro (chiffres uniquement).
    static func detect(from number: String) -> CardNetwork {
        let digits = number.filter(\.isNumber)
        guard let first = digits.first else { return .unknown }
        let two = digits.count >= 2 ? Int(digits.prefix(2)) ?? 0 : 0
        let four = digits.count >= 4 ? Int(digits.prefix(4)) ?? 0 : 0

        if first == "4" { return .visa }
        if two == 34 || two == 37 { return .amex }
        if (51...55).contains(two) || (2221...2720).contains(four) { return .mastercard }
        if two == 65 || four == 6011 { return .discover }
        return .unknown
    }

    /// Longueurs de numéro valides pour le réseau (nombre de chiffres).
    var validLengths: Set<Int> {
        switch self {
        case .visa:       return [13, 16, 19]
        case .mastercard: return [16]
        case .amex:       return [15]
        case .discover:   return [16, 19]
        case .unknown:    return Set(12...19)
        }
    }
}

/// Validation d'un numéro de carte bancaire type Apple Wallet.
enum CardValidator {

    /// Résultat détaillé de la validation d'un numéro.
    struct Result {
        var isLuhnValid: Bool
        var hasValidLength: Bool
        var network: CardNetwork

        /// Le numéro est complet et cohérent (réseau + longueur + Luhn).
        var isValid: Bool { isLuhnValid && hasValidLength }
    }

    /// Algorithme de Luhn : valide la clé de contrôle d'un numéro de carte.
    static func passesLuhn(_ number: String) -> Bool {
        let digits = number.compactMap { $0.wholeNumberValue }
        guard digits.count >= 2 else { return false }
        var sum = 0
        // On double un chiffre sur deux en partant de la droite.
        for (offset, digit) in digits.reversed().enumerated() {
            if offset % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        return sum % 10 == 0
    }

    /// Valide un numéro complet (réseau, longueur, Luhn).
    static func validate(_ number: String) -> Result {
        let digits = number.filter(\.isNumber)
        let network = CardNetwork.detect(from: digits)
        let hasLength = network.validLengths.contains(digits.count)
        let luhn = passesLuhn(digits)
        return Result(isLuhnValid: luhn, hasValidLength: hasLength, network: network)
    }

    /// Valide une date d'expiration au format MM/AA, non expirée.
    static func isExpiryValid(_ expiry: String) -> Bool {
        let parts = expiry.split(separator: "/")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let yearShort = Int(parts[1]),
              (1...12).contains(month) else {
            return false
        }
        // AA -> 20AA. On compare au mois courant.
        let fullYear = 2000 + yearShort
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let nowComponents = calendar.dateComponents([.year, .month], from: now)
        guard let nowYear = nowComponents.year, let nowMonth = nowComponents.month else {
            return false
        }
        if fullYear > nowYear { return true }
        if fullYear < nowYear { return false }
        return month >= nowMonth
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

    // --- Communs ---
    var note: String                 // note libre de l'utilisateur
    var createdAt: Date              // date d'ajout

    init(
        id: UUID = UUID(),
        kind: CardKind,
        name: String,
        colorHex: String = "#4C8DFF",
        code: String = "",
        format: BarcodeFormat = .auto,
        holder: String = "",
        expiry: String = "",
        lastFour: String = "",
        note: String = "",
        createdAt: Date = Date()
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
        self.note = note
        self.createdAt = createdAt
    }

    // Décodage tolérant : les cartes déjà enregistrées (avant l'ajout de
    // `note`/`createdAt`) ne possèdent pas ces clés → valeurs par défaut.
    enum CodingKeys: String, CodingKey {
        case id, kind, name, colorHex, code, format, holder, expiry, lastFour, note, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(UUID.self, forKey: .id)
        kind     = try c.decode(CardKind.self, forKey: .kind)
        name     = try c.decode(String.self, forKey: .name)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        code     = try c.decodeIfPresent(String.self, forKey: .code) ?? ""
        format   = try c.decodeIfPresent(BarcodeFormat.self, forKey: .format) ?? .auto
        holder   = try c.decodeIfPresent(String.self, forKey: .holder) ?? ""
        expiry   = try c.decodeIfPresent(String.self, forKey: .expiry) ?? ""
        lastFour = try c.decodeIfPresent(String.self, forKey: .lastFour) ?? ""
        note     = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    /// Réseau bancaire déduit des 4 derniers chiffres n'est pas fiable ;
    /// on ne l'estime qu'à partir d'un numéro complet, au moment de la saisie.
    var networkFromLastFour: CardNetwork { .unknown }
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
