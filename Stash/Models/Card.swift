import Foundation
import SwiftUI

/// Type de carte géré par l'app.
enum CardKind: String, Codable, CaseIterable, Identifiable {
    // L'ordre de déclaration fixe l'ordre d'affichage des tuiles de choix.
    case bank         // carte bancaire (stockée chiffrée, consultation seule)
    case loyalty      // carte de fidélité (code-barres / QR)
    case other        // autre carte (transport, mutuelle, badge… code optionnel)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .loyalty: return "Fidélité"
        case .bank:    return "Bancaire"
        case .other:   return "Autre"
        }
    }
}

/// Format de code affiché pour une carte de fidélité ou d'accès.
enum BarcodeFormat: String, Codable, CaseIterable, Identifiable {
    case auto
    case code128
    case ean13
    case ean8
    case upca
    case qr
    case pdf417
    case aztec

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto:    return "Automatique"
        case .code128: return "Code-barres (CODE128)"
        case .ean13:   return "Code-barres (EAN-13)"
        case .ean8:    return "Code-barres (EAN-8)"
        case .upca:    return "Code-barres (UPC-A)"
        case .qr:      return "QR Code"
        case .pdf417:  return "PDF417 (Billets / Transport)"
        case .aztec:   return "Aztec (Titres / Badges)"
        }
    }
}

/// Réseau d'une carte bancaire, déduit du préfixe du numéro (règles IIN simplifiées).
enum CardNetwork: String, Codable, CaseIterable, Identifiable {
    case visa
    case mastercard
    case amex
    case discover
    case unknown

    var id: String { rawValue }

    /// Réseaux proposés au choix manuel de l'utilisateur (hors `.unknown`, qui
    /// représente « aucun / automatique »).
    static var selectable: [CardNetwork] { [.visa, .mastercard, .amex, .discover] }

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

    /// Nombre de chiffres regroupés par bloc pour l'affichage du numéro.
    /// Amex se présente en 4-6-5 ; les autres réseaux en groupes de 4.
    var groupSizes: [Int] {
        switch self {
        case .amex: return [4, 6, 5]
        default:    return [4, 4, 4, 4]
        }
    }

    /// Dégradé de marque affiché sur la carte réaliste quand l'utilisateur
    /// n'a pas choisi de couleur personnalisée (couleur par défaut).
    var brandColors: [String] {
        switch self {
        case .visa:       return ["#1A1F71", "#2A4BD7"]
        case .mastercard: return ["#EB001B", "#F79E1B"]
        case .amex:       return ["#016FD0", "#28B0E5"]
        case .discover:   return ["#F27712", "#FFA630"]
        case .unknown:    return ["#3A3A3C", "#1C1C1E"]
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
struct Card: Identifiable, Codable, Equatable, Hashable {
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

    /// Réseau figé à la saisie (Visa/Mastercard/…), stocké en clair car non
    /// sensible. Permet d'afficher le bon logo à l'accueil sans relire le
    /// Keychain (qui exigerait Face ID sur chaque vignette).
    var networkRaw: String           // CardNetwork.rawValue, "" si inconnu

    /// Réseau/design choisi MANUELLEMENT par l'utilisateur dans le formulaire
    /// (Visa/Mastercard/Amex/Discover). Prime sur la détection automatique quand
    /// il est renseigné. Vide = « Automatique » (on retombe sur `networkRaw`).
    /// Non sensible : c'est une préférence d'apparence, pas le numéro.
    var manualNetworkRaw: String

    /// Banque émettrice détectée hors-ligne à la saisie (ex. « BNP Paribas »),
    /// ou chaîne vide. Non sensible : c'est une info de marque, pas le numéro.
    var bankName: String

    /// Couleur de marque principale de la banque détectée (hex), figée à la
    /// saisie. Vide si banque inconnue. Permet d'habiller la carte à l'accueil
    /// sans avoir le BIN complet (on ne garde que les 4 derniers chiffres).
    var bankColorHex: String

    // --- Communs ---
    var note: String                 // note libre de l'utilisateur
    var createdAt: Date              // date d'ajout

    /// Carte épinglée en favori (affichée en tête de liste et avec une étoile).
    var isFavorite: Bool

    /// Horodatage de dernière consultation ou utilisation de la carte.
    var lastUsedAt: Date?

    /// Identifiant du design de carte officiel intégré ("" si utilisation de la couleur/photo).
    var designID: String

    /// Indique si la puce physique EMV doit être affichée (désactivable si le visuel CardArt en a déjà une imprimée).
    var showChip: Bool

    /// L'utilisateur a-t-il associé une image de fond à cette carte ? Le fichier
    /// lui-même vit dans `ArtVault` (dossier Application Support), indexé par
    /// `id` ; on ne garde ici qu'un drapeau non sensible pour savoir s'il faut
    /// tenter de la charger, sans lire le disque à chaque rendu de vignette.
    var hasCustomArt: Bool

    init(
        id: UUID = UUID(),
        kind: CardKind,
        name: String,
        colorHex: String = "#D62836",
        code: String = "",
        format: BarcodeFormat = .auto,
        holder: String = "",
        expiry: String = "",
        lastFour: String = "",
        networkRaw: String = "",
        manualNetworkRaw: String = "",
        bankName: String = "",
        bankColorHex: String = "",
        note: String = "",
        createdAt: Date = Date(),
        hasCustomArt: Bool = false,
        isFavorite: Bool = false,
        lastUsedAt: Date? = nil,
        designID: String = "",
        showChip: Bool = true
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
        self.networkRaw = networkRaw
        self.manualNetworkRaw = manualNetworkRaw
        self.bankName = bankName
        self.bankColorHex = bankColorHex
        self.note = note
        self.createdAt = createdAt
        self.hasCustomArt = hasCustomArt
        self.isFavorite = isFavorite
        self.lastUsedAt = lastUsedAt
        self.designID = designID
        self.showChip = showChip
    }

    // Décodage tolérant : les cartes déjà enregistrées (avant l'ajout de
    // `note`/`createdAt`/`isFavorite`/`lastUsedAt`/`designID`/`showChip`) ne possèdent pas ces clés → valeurs par défaut.
    enum CodingKeys: String, CodingKey {
        case id, kind, name, colorHex, code, format, holder, expiry, lastFour, networkRaw, manualNetworkRaw, bankName, bankColorHex, note, createdAt, hasCustomArt, isFavorite, lastUsedAt, designID, showChip
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
        networkRaw = try c.decodeIfPresent(String.self, forKey: .networkRaw) ?? ""
        manualNetworkRaw = try c.decodeIfPresent(String.self, forKey: .manualNetworkRaw) ?? ""
        bankName = try c.decodeIfPresent(String.self, forKey: .bankName) ?? ""
        bankColorHex = try c.decodeIfPresent(String.self, forKey: .bankColorHex) ?? ""
        note     = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        hasCustomArt = try c.decodeIfPresent(Bool.self, forKey: .hasCustomArt) ?? false
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        lastUsedAt = try c.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        designID = try c.decodeIfPresent(String.self, forKey: .designID) ?? ""
        showChip = try c.decodeIfPresent(Bool.self, forKey: .showChip) ?? true
    }

    /// Réseau bancaire utilisé pour l'apparence. Priorité au choix MANUEL de
    /// l'utilisateur ; à défaut, réseau figé à la saisie (détecté du numéro).
    /// Repli sur `.unknown` pour les cartes enregistrées avant l'ajout de ce
    /// champ (re-détectées à la prochaine édition, ou dégradé personnalisé).
    var network: CardNetwork {
        if let manual = CardNetwork(rawValue: manualNetworkRaw), manual != .unknown {
            return manual
        }
        return CardNetwork(rawValue: networkRaw) ?? .unknown
    }
}

/// Palette de couleurs proposée à l'ajout d'une carte.
/// Thème rouge/noir : rouges, bordeaux et nuances sombres en priorité.
enum Palette {
    static let colors: [String] = [
        "#D62836", "#E1394A", "#9E1B26", "#7A1520",
        "#B8232F", "#FF375F", "#3A3A3C", "#2A2A2E",
        "#1C1C1E", "#0F0F11"
    ]
}

extension Color {
    /// Crée une `Color` à partir d'une chaîne hexadécimale.
    /// Formats acceptés : `#RGB`, `#RRGGBB`, `#RRGGBBAA` (le `#` est optionnel).
    /// Une chaîne invalide retombe sur la couleur d'accent de l'app plutôt
    /// que sur un bleu arbitraire, pour rester cohérent avec le thème.
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))

        // On vérifie que tout est hexadécimal ET que la longueur est connue.
        let isHex = !cleaned.isEmpty
            && cleaned.allSatisfy { $0.isHexDigit }
            && [3, 6, 8].contains(cleaned.count)

        guard isHex else {
            // Repli sur le rouge d'accent (thème rouge/noir) au lieu d'un bleu hors-sujet.
            self.init(.sRGB, red: 0.882, green: 0.180, blue: 0.235, opacity: 1.0)
            return
        }

        // On normalise en 8 chiffres (RRGGBBAA) pour un seul chemin de calcul.
        let normalized: String
        switch cleaned.count {
        case 3:
            // #RGB -> #RRGGBBFF
            normalized = cleaned.map { "\($0)\($0)" }.joined() + "FF"
        case 6:
            // #RRGGBB -> #RRGGBBFF
            normalized = cleaned + "FF"
        default:
            // Déjà #RRGGBBAA
            normalized = cleaned
        }

        var value: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&value)

        let r = Double((value & 0xFF00_0000) >> 24) / 255.0
        let g = Double((value & 0x00FF_0000) >> 16) / 255.0
        let b = Double((value & 0x0000_FF00) >> 8) / 255.0
        let a = Double(value & 0x0000_00FF) / 255.0

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Couleur d'accent de l'app (thème rouge/noir), utilisée comme tint global.
    static let stashRed = Color(hex: "#E12E3C")
}
