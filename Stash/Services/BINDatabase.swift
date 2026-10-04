import Foundation

/// Résolution **100 % hors-ligne** d'un numéro de carte bancaire vers sa banque
/// émettrice et ses couleurs de marque, à partir du BIN/IIN (les 6 à 8 premiers
/// chiffres). Aucune requête réseau : la base est embarquée dans l'app, ce qui
/// respecte la promesse « aucune donnée n'est envoyée sur un serveur ».
///
/// La couverture est volontairement centrée sur les émetteurs français les plus
/// courants. Un BIN inconnu retombe proprement sur `nil` (banque) et sur les
/// couleurs du réseau (Visa/Mastercard/…), déjà gérées par `CardNetwork`.
enum BINDatabase {

    /// Information de marque déduite d'un numéro de carte.
    struct BrandInfo: Equatable {
        /// Nom lisible de la banque émettrice (ex. « Crédit Agricole »), ou `nil`.
        let bankName: String?
        /// Couleurs de dégradé de la banque (hex), ou `nil` pour retomber sur
        /// le dégradé du réseau.
        let brandColors: [String]?
    }

    /// Un émetteur : ses préfixes BIN, son nom et ses couleurs de marque.
    struct Issuer {
        let name: String
        let colors: [String]
        /// Préfixes BIN (chaînes de chiffres). Le plus long préfixe qui
        /// correspond l'emporte (matching le plus spécifique).
        let prefixes: [String]
    }

    /// Base embarquée des émetteurs français courants. Les préfixes sont des
    /// plages IIN publiques largement documentées ; ils identifient la banque,
    /// jamais le porteur. Couleurs = charte de marque approximative.
    static let issuers: [Issuer] = [
        Issuer(
            name: "Crédit Agricole",
            colors: ["#006A4E", "#00A66C"],
            prefixes: ["497103", "497104", "455730", "513209", "497010"]
        ),
        Issuer(
            name: "BNP Paribas",
            colors: ["#00915A", "#007A47"],
            prefixes: ["497178", "497179", "513210", "455675", "497200"]
        ),
        Issuer(
            name: "Société Générale",
            colors: ["#E9041E", "#1D1D1B"],
            prefixes: ["497201", "513211", "455674", "497030"]
        ),
        Issuer(
            name: "Caisse d'Épargne",
            colors: ["#E2001A", "#7A0010"],
            prefixes: ["513250", "513251", "497080", "455620"]
        ),
        Issuer(
            name: "Banque Populaire",
            colors: ["#005EB8", "#0091DA"],
            prefixes: ["513260", "513261", "497090", "455621"]
        ),
        Issuer(
            name: "La Banque Postale",
            colors: ["#003DA5", "#FFCC00"],
            prefixes: ["497040", "497041", "513270", "455680"]
        ),
        Issuer(
            name: "Crédit Mutuel",
            colors: ["#E30613", "#B3040F"],
            prefixes: ["497060", "497061", "513280", "455690"]
        ),
        Issuer(
            name: "CIC",
            colors: ["#003B7A", "#0059B3"],
            prefixes: ["497062", "513281", "455691"]
        ),
        Issuer(
            name: "LCL",
            colors: ["#003DA5", "#0072CE"],
            prefixes: ["497050", "497051", "513290", "455670"]
        ),
        Issuer(
            name: "HSBC France",
            colors: ["#DB0011", "#1D1D1B"],
            prefixes: ["497120", "513300", "455700"]
        ),
        Issuer(
            name: "Boursorama",
            colors: ["#EC008C", "#7A0048"],
            prefixes: ["497130", "513310", "455710"]
        ),
        Issuer(
            name: "Revolut",
            colors: ["#0666EB", "#1D1D1B"],
            prefixes: ["516830", "539931", "428210", "473324"]
        ),
        Issuer(
            name: "N26",
            colors: ["#1D1D1B", "#48484A"],
            prefixes: ["531984", "533472", "530127"]
        )
    ]

    /// Résout un numéro (ou un BIN) vers sa banque et ses couleurs de marque.
    /// - Parameter number: numéro complet ou partiel ; seuls les chiffres sont lus.
    /// - Returns: `BrandInfo` avec la banque et ses couleurs si un préfixe
    ///   correspond, sinon `BrandInfo(bankName: nil, brandColors: nil)`.
    static func brandInfo(for number: String) -> BrandInfo {
        let digits = number.filter(\.isNumber)
        guard digits.count >= 6 else {
            return BrandInfo(bankName: nil, brandColors: nil)
        }

        // On garde le préfixe le plus long qui correspond (plus spécifique).
        var best: (issuer: Issuer, length: Int)?
        for issuer in issuers {
            for prefix in issuer.prefixes where digits.hasPrefix(prefix) {
                if best == nil || prefix.count > best!.length {
                    best = (issuer, prefix.count)
                }
            }
        }

        guard let match = best?.issuer else {
            return BrandInfo(bankName: nil, brandColors: nil)
        }
        return BrandInfo(bankName: match.name, brandColors: match.colors)
    }
}
