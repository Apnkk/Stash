import Foundation
import UIKit

/// Stockage local des images de fond ("card art") choisies par l'utilisateur.
///
/// Contrairement à `SecureVault` (Keychain), ces images ne sont pas des secrets
/// bancaires : on les range dans un sous-dossier du répertoire Application Support,
/// hors périmètre iCloud/backup, avec `.completeFileProtection` pour qu'elles soient
/// illisibles quand l'appareil est verrouillé. Chaque image est référencée par
/// l'`id` de la carte (une image au plus par carte).
enum ArtVault {

    /// Erreurs remontées à l'appelant pour un retour UI explicite.
    enum ArtError: Error, LocalizedError {
        case encodingFailed
        case writeFailed(Error)
        case directoryFailed(Error)

        var errorDescription: String? {
            switch self {
            case .encodingFailed:        return "Impossible de préparer l'image."
            case .writeFailed(let e):    return "Échec d'enregistrement de l'image : \(e.localizedDescription)"
            case .directoryFailed(let e): return "Impossible de préparer le dossier des images : \(e.localizedDescription)"
            }
        }
    }

    /// Largeur maximale de l'image stockée. Un card art n'a pas besoin d'être
    /// plus large que ça pour un rendu net sur une vignette/carte plein cadre,
    /// et on évite de garder des fichiers de plusieurs Mo pour rien.
    private static let maxDimension: CGFloat = 1024

    /// Qualité JPEG du fichier stocké. 0.85 = bon compromis netteté/taille.
    private static let jpegQuality: CGFloat = 0.85

    /// Cache mémoire des images décodées, pour éviter de relire le disque et
    /// de re-décoder le JPEG à chaque recomposition SwiftUI (défilement, halo…).
    /// `NSCache` se vide tout seul sous pression mémoire.
    private static let cache = NSCache<NSString, UIImage>()

    /// Dossier `Application Support/CardArt`, créé au besoin et exclu des backups.
    private static func directory() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("CardArt", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                throw ArtError.directoryFailed(error)
            }
            // Exclut le dossier des sauvegardes iCloud/iTunes : ces images
            // restent purement locales à l'appareil.
            var mutableDir = dir
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? mutableDir.setResourceValues(values)
        }
        return dir
    }

    /// URL du fichier image d'une carte (qu'il existe ou non).
    private static func fileURL(for key: String) throws -> URL {
        try directory().appendingPathComponent("\(key).jpg", isDirectory: false)
    }

    /// Enregistre (ou remplace) l'image de fond d'une carte.
    /// L'image est redimensionnée et ré-encodée en JPEG protégé.
    static func save(_ image: UIImage, for key: String) throws {
        let scaled = downscaled(image, to: maxDimension)
        guard let data = scaled.jpegData(compressionQuality: jpegQuality) else {
            throw ArtError.encodingFailed
        }
        let url = try fileURL(for: key)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            throw ArtError.writeFailed(error)
        }
        // Remplace l'entrée en cache par la nouvelle image (déjà redimensionnée).
        cache.setObject(scaled, forKey: key as NSString)
    }

    /// Charge l'image de fond d'une carte, ou `nil` si aucune (ou verrouillée).
    /// Le résultat est mis en cache mémoire par clé.
    static func load(_ key: String) -> UIImage? {
        let cacheKey = key as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        guard let url = try? fileURL(for: key),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        cache.setObject(image, forKey: cacheKey)
        return image
    }

    /// Indique si une carte possède une image de fond stockée.
    static func exists(_ key: String) -> Bool {
        guard let url = try? fileURL(for: key) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Liste toutes les clés (id de carte) ayant une image stockée.
    static func allKeys() -> Set<String> {
        guard let dir = try? directory(),
              let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            return []
        }
        return Set(
            names
                .filter { $0.hasSuffix(".jpg") }
                .map { String($0.dropLast(4)) }
        )
    }

    /// Supprime l'image de fond d'une carte. Sans effet si aucune n'existe.
    static func delete(_ key: String) {
        cache.removeObject(forKey: key as NSString)
        guard let url = try? fileURL(for: key) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Réduit une image pour que sa plus grande dimension ne dépasse pas `max`,
    /// en conservant le ratio. Les images déjà plus petites sont renvoyées telles quelles.
    private static func downscaled(_ image: UIImage, to max: CGFloat) -> UIImage {
        let size = image.size
        let largest = Swift.max(size.width, size.height)
        guard largest > max, largest > 0 else { return image }

        let ratio = max / largest
        let target = CGSize(width: size.width * ratio, height: size.height * ratio)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
