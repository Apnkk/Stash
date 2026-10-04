import Foundation
import UIKit
import Vision

/// Service de reconnaissance visuelle (Vision) pour cartes de fidélité et cartes bancaires.
/// Fonctionne 100 % en local sur l'appareil (on-device Apple Vision), aucune connexion requise.
enum CardScanner {

    /// Extrait un numéro de carte bancaire valide (Luhn) et une date d'expiration éventuelle
    /// à partir d'un ensemble de lignes de texte reconnues.
    static func extractBankCardInfo(from textLines: [String]) -> (number: String, expiry: String?)? {
        var foundNumber: String?
        var foundExpiry: String?

        // Regex pour dates d'expiration (MM/AA ou MM/AAAA)
        let expiryRegex = try? NSRegularExpression(pattern: "\\b(0[1-9]|1[0-2])\\s*[/.-]\\s*([2-9][0-9])\\b")

        for line in textLines {
            let digitsOnly = line.filter(\.isNumber)

            // Recherche de numéro de carte (13 à 19 chiffres consécutifs ou groupés)
            if digitsOnly.count >= 13 && digitsOnly.count <= 19 {
                if CardValidator.passesLuhn(digitsOnly) && foundNumber == nil {
                    foundNumber = digitsOnly
                }
            }

            // Recherche d'expiration
            if foundExpiry == nil, let regex = expiryRegex {
                let range = NSRange(location: 0, length: line.utf16.count)
                if let match = regex.firstMatch(in: line, options: [], range: range) {
                    if let mRange = Range(match.range(at: 1), in: line),
                       let yRange = Range(match.range(at: 2), in: line) {
                        let mm = String(line[mRange])
                        let yy = String(line[yRange])
                        let candidate = "\(mm)/\(yy)"
                        if CardValidator.isExpiryValid(candidate) {
                            foundExpiry = candidate
                        }
                    }
                }
            }
        }

        if let number = foundNumber {
            return (number, foundExpiry)
        }
        return nil
    }

    /// Analyse une image (ex. capture d'écran de carte de fidélité) pour détecter un code-barres.
    static func scanBarcode(from image: UIImage) async -> (payload: String, format: BarcodeFormat)? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNBarcodeObservation],
                      let first = results.first,
                      let payload = first.payloadStringValue else {
                    continuation.resume(returning: nil)
                    return
                }

                let format = mapSymbology(first.symbology)
                continuation.resume(returning: (payload, format))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    /// Analyse une image de carte bancaire pour en extraire le numéro et l'expiration via OCR Vision.
    static func scanBankCard(from image: UIImage) async -> (number: String, expiry: String?)? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let result = extractBankCardInfo(from: lines)
                continuation.resume(returning: result)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    /// Associe une symbologie Vision au format d'affichage interne `BarcodeFormat`.
    static func mapSymbology(_ symbology: VNBarcodeSymbology) -> BarcodeFormat {
        switch symbology {
        case .qr:
            return .qr
        case .ean13:
            return .ean13
        case .ean8:
            return .ean8
        case .code128:
            return .code128
        case .pdf417:
            return .pdf417
        case .aztec:
            return .aztec
        default:
            return .code128
        }
    }
}
