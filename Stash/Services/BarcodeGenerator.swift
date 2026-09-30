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
            // CoreImage n'a pas de générateur EAN-13 natif : on retombe
            // proprement sur CODE128, qui reste scannable en caisse.
            let filter = CIFilter.code128BarcodeGenerator()
            filter.message = data
            filter.quietSpace = 2
            outputImage = filter.outputImage
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
}
