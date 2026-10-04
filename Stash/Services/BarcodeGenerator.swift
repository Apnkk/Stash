import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Génère l'image d'un code-barres (1D ou 2D) à partir d'une valeur texte,
/// entièrement hors ligne via CoreImage et encodeurs natifs (aucune dépendance).
enum BarcodeGenerator {

    private static let context = CIContext()

    /// Détermine le format effectif quand l'utilisateur a laissé "auto".
    static func resolvedFormat(for card: Card) -> BarcodeFormat {
        if card.format != .auto { return card.format }
        let code = card.code.trimmingCharacters(in: .whitespacesAndNewlines)

        // 8 chiffres -> EAN-8
        if code.range(of: "^\\d{8}$", options: .regularExpression) != nil {
            let digits = code.compactMap { $0.wholeNumberValue }
            if digits.count == 8 && digits[7] == ean8CheckDigit(Array(digits.prefix(7))) {
                return .ean8
            }
            return .code128
        }

        // 12 chiffres -> UPC-A
        if code.range(of: "^\\d{12}$", options: .regularExpression) != nil {
            let digits = code.compactMap { $0.wholeNumberValue }
            if digits.count == 12 && digits[11] == upcaCheckDigit(Array(digits.prefix(11))) {
                return .upca
            }
            return .code128
        }

        // 13 chiffres -> EAN-13
        if code.range(of: "^\\d{13}$", options: .regularExpression) != nil {
            let digits = code.compactMap { $0.wholeNumberValue }
            if digits.count == 13 && digits[12] == ean13CheckDigit(Array(digits.prefix(12))) {
                return .ean13
            }
            // Clé invalide pour EAN-13 : bascule sur CODE128 pour ne pas altérer les chiffres
            return .code128
        }

        // Alphanumérique jusqu'à 48 caractères -> Code128
        if code.range(of: "^[0-9A-Za-z\\-.$/+% ]{1,48}$", options: .regularExpression) != nil {
            return .code128
        }

        // Valeur complexe, URL ou texte long -> QR Code
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

        case .pdf417:
            let filter = CIFilter.pdf417BarcodeGenerator()
            filter.message = data
            outputImage = filter.outputImage

        case .aztec:
            let filter = CIFilter.aztecCodeGenerator()
            filter.message = data
            outputImage = filter.outputImage

        case .ean13:
            return ean13Image(for: card.code, scale: scale)

        case .ean8:
            return ean8Image(for: card.code, scale: scale)

        case .upca:
            return upcaImage(for: card.code, scale: scale)

        case .auto:
            return nil
        }

        guard let ciImage = outputImage else { return nil }

        let transformed = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Encodage EAN-13

    private enum EAN13 {
        static let left_A = [
            "0001101", "0011001", "0010011", "0111101", "0100011",
            "0110001", "0101111", "0111011", "0110111", "0001011"
        ]
        static let left_B = [
            "0100111", "0110011", "0011011", "0100001", "0011101",
            "0111001", "0000101", "0010001", "0001001", "0010111"
        ]
        static let right_C = [
            "1110010", "1100110", "1101100", "1000010", "1011100",
            "1001110", "1010000", "1000100", "1001000", "1110100"
        ]
        static let parity = [
            "AAAAAA", "AABABB", "AABBAB", "AABBBA", "ABAABB",
            "ABBAAB", "ABBBAA", "ABABAB", "ABABBA", "ABBABA"
        ]
    }

    /// Calcule la clé de contrôle EAN-13 pour 12 chiffres.
    static func ean13CheckDigit(_ digits: [Int]) -> Int {
        var sum = 0
        for (index, digit) in digits.enumerated() {
            sum += (index % 2 == 0) ? digit : digit * 3
        }
        return (10 - (sum % 10)) % 10
    }

    static func ean13Modules(for code: String) -> [Bool]? {
        let digits = code.compactMap { $0.wholeNumberValue }
        guard digits.count == 12 || digits.count == 13 else { return nil }
        guard digits.allSatisfy({ (0...9).contains($0) }) else { return nil }

        var completeDigits = digits
        if digits.count == 13 {
            let provided = digits[12]
            let expected = ean13CheckDigit(Array(digits.prefix(12)))
            guard provided == expected else { return nil }
        } else {
            completeDigits.append(ean13CheckDigit(digits))
        }

        let first = completeDigits[0]
        let leftDigits = Array(completeDigits[1...6])
        let rightDigits = Array(completeDigits[7...12])
        let pattern = Array(EAN13.parity[first])

        var bits = ""
        bits += "101" // garde début

        for (index, digit) in leftDigits.enumerated() {
            bits += (pattern[index] == "A") ? EAN13.left_A[digit] : EAN13.left_B[digit]
        }

        bits += "01010" // garde centrale

        for digit in rightDigits {
            bits += EAN13.right_C[digit]
        }

        bits += "101" // garde fin
        return bits.map { $0 == "1" }
    }

    private static func ean13Image(for code: String, scale: CGFloat) -> UIImage? {
        guard let modules = ean13Modules(for: code) else { return nil }
        return renderBarcode(modules: modules, scale: scale)
    }

    // MARK: - Encodage EAN-8

    /// Clé de contrôle EAN-8 pour 7 chiffres.
    static func ean8CheckDigit(_ digits: [Int]) -> Int {
        var sum = 0
        for (index, digit) in digits.enumerated() {
            sum += (index % 2 == 0) ? digit * 3 : digit
        }
        return (10 - (sum % 10)) % 10
    }

    static func ean8Modules(for code: String) -> [Bool]? {
        let digits = code.compactMap { $0.wholeNumberValue }
        guard digits.count == 7 || digits.count == 8 else { return nil }
        guard digits.allSatisfy({ (0...9).contains($0) }) else { return nil }

        var completeDigits = digits
        if digits.count == 8 {
            let provided = digits[7]
            let expected = ean8CheckDigit(Array(digits.prefix(7)))
            guard provided == expected else { return nil }
        } else {
            completeDigits.append(ean8CheckDigit(digits))
        }

        let leftDigits = Array(completeDigits[0...3])
        let rightDigits = Array(completeDigits[4...7])

        var bits = "101" // garde début
        for digit in leftDigits {
            bits += EAN13.left_A[digit]
        }
        bits += "01010" // garde centrale
        for digit in rightDigits {
            bits += EAN13.right_C[digit]
        }
        bits += "101" // garde fin

        return bits.map { $0 == "1" }
    }

    private static func ean8Image(for code: String, scale: CGFloat) -> UIImage? {
        guard let modules = ean8Modules(for: code) else { return nil }
        return renderBarcode(modules: modules, scale: scale)
    }

    // MARK: - Encodage UPC-A

    /// Clé de contrôle UPC-A pour 11 chiffres.
    static func upcaCheckDigit(_ digits: [Int]) -> Int {
        var sum = 0
        for (index, digit) in digits.enumerated() {
            sum += (index % 2 == 0) ? digit * 3 : digit
        }
        return (10 - (sum % 10)) % 10
    }

    static func upcaModules(for code: String) -> [Bool]? {
        let digits = code.compactMap { $0.wholeNumberValue }
        guard digits.count == 11 || digits.count == 12 else { return nil }
        guard digits.allSatisfy({ (0...9).contains($0) }) else { return nil }

        var completeDigits = digits
        if digits.count == 12 {
            let provided = digits[11]
            let expected = upcaCheckDigit(Array(digits.prefix(11)))
            guard provided == expected else { return nil }
        } else {
            completeDigits.append(upcaCheckDigit(digits))
        }

        // UPC-A équivaut à un code EAN-13 débutant par 0
        let ean13String = "0" + completeDigits.map(String.init).joined()
        return ean13Modules(for: ean13String)
    }

    private static func upcaImage(for code: String, scale: CGFloat) -> UIImage? {
        guard let modules = upcaModules(for: code) else { return nil }
        return renderBarcode(modules: modules, scale: scale)
    }

    // MARK: - Rendu graphique générique 1D

    private static func renderBarcode(modules: [Bool], scale: CGFloat) -> UIImage? {
        guard !modules.isEmpty else { return nil }

        let moduleWidth = max(1, Int(scale.rounded()))
        let quietModules = 9            // marge silencieuse recommandée à gauche/droite
        let totalModules = modules.count + quietModules * 2
        let width = totalModules * moduleWidth
        let height = max(moduleWidth * 20, 60)
        let size = CGSize(width: width, height: height)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { rendererContext in
            let ctx = rendererContext.cgContext
            // Fond blanc.
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))

            // Barres noires.
            ctx.setFillColor(UIColor.black.cgColor)
            for (index, isBar) in modules.enumerated() where isBar {
                let x = (quietModules + index) * moduleWidth
                ctx.fill(CGRect(x: x, y: 0, width: moduleWidth, height: height))
            }
        }
    }
}
