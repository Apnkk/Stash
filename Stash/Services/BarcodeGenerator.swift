import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Génère l'image d'un code-barres ou d'un QR à partir d'une valeur texte,
/// entièrement hors ligne via CoreImage (aucune dépendance externe).
enum BarcodeGenerator {

    private static let context = CIContext()

    /// Détermine le format effectif quand l'utilisateur a laissé "auto".
    static func resolvedFormat(for card: Card) -> BarcodeFormat {
        if card.format != .auto { return card.format }
        let code = card.code
        if code.range(of: "^\\d{13}$", options: .regularExpression) != nil {
            return .ean13
        }
        if code.range(of: "^[0-9A-Za-z\\-.$/+% ]{1,48}$", options: .regularExpression) != nil {
            return .code128
        }
        return .qr
    }

    /// Produit une `UIImage` nette (mise à l'échelle) pour la carte donnée.
    /// Renvoie `nil` si la valeur est invalide pour le format demandé.
    static func image(for card: Card, scale: CGFloat = 10) -> UIImage? {
        let format = resolvedFormat(for: card)
        let data = Data(card.code.utf8)

        let outputImage: CIImage?
        switch format {
        case .qr:
            let filter = CIFilter.qrCodeGenerator()
            filter.message = data
            filter.correctionLevel = "M"
            outputImage = filter.outputImage
        case .code128:
            let filter = CIFilter.code128BarcodeGenerator()
            filter.message = data
            filter.quietSpace = 2
            outputImage = filter.outputImage
        case .ean13:
            // CoreImage n'a pas de générateur EAN-13 : on encode nous-mêmes
            // le motif de barres, puis on le rend en image nette.
            return ean13Image(for: card.code, scale: scale)
        case .auto:
            return nil // résolu plus haut, jamais atteint
        }

        guard let ciImage = outputImage else { return nil }

        let transformed = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Encodage EAN-13

    /// Tables d'encodage EAN-13.
    /// Chaque motif est décrit par ses 7 modules (barre = 1, espace = 0).
    private enum EAN13 {
        /// Éléments de gauche, ensemble A (impair).
        static let left_A = [
            "0001101", "0011001", "0010011", "0111101", "0100011",
            "0110001", "0101111", "0111011", "0110111", "0001011"
        ]
        /// Éléments de gauche, ensemble B (pair).
        static let left_B = [
            "0100111", "0110011", "0011011", "0100001", "0011101",
            "0111001", "0000101", "0010001", "0001001", "0010111"
        ]
        /// Éléments de droite, ensemble C.
        static let right_C = [
            "1110010", "1100110", "1101100", "1000010", "1011100",
            "1001110", "1010000", "1000100", "1001000", "1110100"
        ]
        /// Choix A/B des 6 premiers chiffres, en fonction du premier chiffre.
        static let parity = [
            "AAAAAA", "AABABB", "AABBAB", "AABBBA", "ABAABB",
            "ABBAAB", "ABBBAA", "ABABAB", "ABABBA", "ABBABA"
        ]
    }

    /// Calcule la clé de contrôle EAN-13 pour 12 chiffres.
    private static func ean13CheckDigit(_ digits: [Int]) -> Int {
        var sum = 0
        for (index, digit) in digits.enumerated() {
            sum += (index % 2 == 0) ? digit : digit * 3
        }
        return (10 - (sum % 10)) % 10
    }

    /// Construit la suite de modules (1 = barre, 0 = espace) d'un EAN-13
    /// valide, ou `nil` si la valeur n'est pas un EAN-13 exploitable.
    private static func ean13Modules(for code: String) -> [Bool]? {
        var digits = code.compactMap { $0.wholeNumberValue }
        // Il faut 12 chiffres (clé calculée) ou 13 chiffres (clé fournie).
        guard digits.count == 12 || digits.count == 13 else { return nil }
        guard digits.allSatisfy({ (0...9).contains($0) }) else { return nil }

        if digits.count == 13 {
            // Vérifie la clé fournie ; si elle est incohérente, on la recalcule.
            let provided = digits[12]
            let expected = ean13CheckDigit(Array(digits.prefix(12)))
            if provided != expected {
                digits[12] = expected
            }
        } else {
            digits.append(ean13CheckDigit(digits))
        }

        let first = digits[0]
        let leftDigits = Array(digits[1...6])
        let rightDigits = Array(digits[7...12])
        let pattern = Array(EAN13.parity[first])

        var bits = ""
        bits += "101" // garde de début

        for (index, digit) in leftDigits.enumerated() {
            bits += (pattern[index] == "A") ? EAN13.left_A[digit] : EAN13.left_B[digit]
        }

        bits += "01010" // garde centrale

        for digit in rightDigits {
            bits += EAN13.right_C[digit]
        }

        bits += "101" // garde de fin

        return bits.map { $0 == "1" }
    }

    /// Produit l'image d'un code EAN-13 à partir des modules encodés.
    private static func ean13Image(for code: String, scale: CGFloat) -> UIImage? {
        guard let modules = ean13Modules(for: code), !modules.isEmpty else { return nil }

        let moduleWidth = max(1, Int(scale.rounded()))
        let quietModules = 9            // marge silencieuse recommandée à gauche/droite
        let totalModules = modules.count + quietModules * 2
        let width = totalModules * moduleWidth
        let height = max(moduleWidth * 20, 60)

        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), true, 1)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        // Fond blanc.
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Barres noires.
        ctx.setFillColor(UIColor.black.cgColor)
        for (index, isBar) in modules.enumerated() where isBar {
            let x = (quietModules + index) * moduleWidth
            ctx.fill(CGRect(x: x, y: 0, width: moduleWidth, height: height))
        }

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
