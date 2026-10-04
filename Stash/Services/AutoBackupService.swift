import Foundation

/// Service de sauvegarde automatique dans un dossier choisi par l'utilisateur
/// (dossier local "Fichiers" ou dossier iCloud Drive), sans avoir besoin d'un compte développeur Apple.
///
/// Utilise les signets sécurisés (`security-scoped bookmarks`) d'Apple pour conserver
/// l'accès en écriture au dossier sélectionné d'une session à l'autre.
enum AutoBackupService {

    private static let bookmarkKey = "auto_backup_folder_bookmark"
    private static let folderNameKey = "auto_backup_folder_name"

    /// L'utilisateur a-t-il configuré un dossier de sauvegarde automatique ?
    static var isEnabled: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    /// Nom d'affichage du dossier cible (ex. "Documents", "iCloud Drive", "Stash").
    static var folderName: String? {
        UserDefaults.standard.string(forKey: folderNameKey)
    }

    /// Enregistre un signet sécurisé pour le dossier choisi via `UIDocumentPickerViewController`.
    static func configureFolder(url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let bookmarkData = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
            UserDefaults.standard.set(url.lastPathComponent, forKey: folderNameKey)
            return true
        } catch {
            return false
        }
    }

    /// Supprime la configuration de sauvegarde automatique.
    static func disable() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: folderNameKey)
    }

    /// Effectue une sauvegarde automatique silencieuse si un dossier est configuré.
    static func performAutoBackup(cards: [Card]) {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else { return }

        var isStale = false
        guard let folderURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return
        }

        if isStale {
            // Renouvelle le signet si le système le signale périmé
            _ = configureFolder(url: folderURL)
        }

        guard folderURL.startAccessingSecurityScopedResource() else { return }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(cards) else { return }

        let targetFile = folderURL.appendingPathComponent("stash-auto-backup.json")
        try? data.write(to: targetFile, options: [.atomic, .completeFileProtection])
    }
}
