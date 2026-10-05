import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var stashBackup: UTType {
        UTType(filenameExtension: "stashbackup") ?? UTType(importedAs: "com.stash.backup")
    }
}

/// Écran Réglages : sécurité, notifications, sauvegarde chiffrée de bout en bout et sauvegarde auto.
struct SettingsView: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AutoLockDelay.storageKey) private var autoLockRaw = AutoLockDelay.thirtySeconds.rawValue
    @AppStorage(ExpiryReminderService.settingsKey) private var expiryRemindersEnabled = false
    @AppStorage("stash_display_mode") private var displayModeRaw = StashDisplayMode.walletStack.rawValue
    @AppStorage(SpotlightService.settingsKey) private var spotlightEnabled = false

    // Sauvegarde chiffrée
    @State private var showingExportPasswordSheet = false
    @State private var showingImportPasswordSheet = false
    @State private var showingEncryptedExporter = false
    @State private var showingPlainExporter = false
    @State private var showingImporter = false
    @State private var showingFolderPicker = false

    @State private var encryptedExportDoc: StashBackupDocument?
    @State private var plainExportDoc: BackupDocument?
    @State private var pendingImportData: Data?

    @State private var autoBackupFolder: String? = AutoBackupService.folderName

    @State private var message: String?
    @State private var messageIsError = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Présentation
                Section {
                    Picker("Affichage des cartes", selection: $displayModeRaw) {
                        ForEach(StashDisplayMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                } header: {
                    Text("Présentation")
                } footer: {
                    Text("La pile Wallet présente vos cartes superposées façon Apple Wallet. La grille les affiche sous forme de liste fluide.")
                }

                // MARK: Sécurité
                Section {
                    Picker("Verrouillage auto", selection: $autoLockRaw) {
                        ForEach(AutoLockDelay.allCases) { delay in
                            Text(delay.label).tag(delay.rawValue)
                        }
                    }
                } header: {
                    Text("Sécurité")
                } footer: {
                    Text("Délai avant que Stash ne redemande Face ID / Touch ID après être passé en arrière-plan. « Immédiat » reverrouille dès que tu quittes l'app.")
                }

                // MARK: Spotlight
                Section {
                    Toggle("Recherche Spotlight (fidélité)", isOn: $spotlightEnabled)
                        .onChange(of: spotlightEnabled) { _, _ in
                            SpotlightService.updateIndex(with: store.cards)
                        }
                } header: {
                    Text("Recherche système")
                } footer: {
                    Text("Permet de retrouver directement tes cartes de fidélité depuis Spotlight. 🔒 Les cartes bancaires sont strictement exclues pour garantir ta confidentialité.")
                }

                // MARK: Notifications
                Section {
                    Toggle("Rappels d'expiration", isOn: $expiryRemindersEnabled)
                        .onChange(of: expiryRemindersEnabled) { _, enabled in
                            Task {
                                if enabled {
                                    let granted = await ExpiryReminderService.requestAuthorization()
                                    if granted {
                                        await ExpiryReminderService.rescheduleAll(for: store.cards)
                                    } else {
                                        expiryRemindersEnabled = false
                                    }
                                } else {
                                    ExpiryReminderService.cancelAll()
                                }
                            }
                        }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Reçois une notification locale 30 jours avant et au début du mois d'expiration de tes cartes bancaires.")
                }

                // MARK: Sauvegarde chiffrée complète
                Section {
                    Button {
                        showingExportPasswordSheet = true
                    } label: {
                        Label("Sauvegarde complète chiffrée…", systemImage: "lock.shield.fill")
                    }
                    .disabled(store.cards.isEmpty)

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Restaurer une sauvegarde…", systemImage: "arrow.counterclockwise.circle.fill")
                    }

                    Menu {
                        Button {
                            preparePlainExport()
                        } label: {
                            Label("Exporter en JSON lisible (sans numéros secrets)", systemImage: "doc.text")
                        }
                    } label: {
                        Label("Options d'export avancées", systemImage: "ellipsis.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .disabled(store.cards.isEmpty)
                } header: {
                    Text("Sauvegarde et Restauration")
                } footer: {
                    Text("La sauvegarde chiffrée (.stashbackup) protège l'intégralité de tes cartes et numéros secrets par un mot de passe fort via AES-256-GCM (PBKDF2).")
                }

                // MARK: Sauvegarde automatique locale
                Section {
                    if let folder = autoBackupFolder {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dossier actif")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(folder)
                                    .font(.body.weight(.medium))
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        Button("Changer de dossier…") {
                            showingFolderPicker = true
                        }

                        Button("Désactiver la sauvegarde auto", role: .destructive) {
                            AutoBackupService.disable()
                            autoBackupFolder = nil
                            show("Sauvegarde automatique désactivée.", isError: false)
                        }
                    } else {
                        Button {
                            showingFolderPicker = true
                        } label: {
                            Label("Choisir un dossier de sauvegarde…", systemImage: "folder.badge.plus")
                        }
                    }
                } header: {
                    Text("Sauvegarde automatique")
                } footer: {
                    Text("Enregistre automatiquement une copie silencieuse de tes cartes dans le dossier sélectionné (Fichiers ou iCloud Drive) à chaque modification.")
                }

                // MARK: Bannière de message
                if let message {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: messageIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(messageIsError ? .red : .green)
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(messageIsError ? .red : .primary)
                        }
                    }
                }

                // MARK: Infos app
                Section {
                    LabeledContent("Cartes enregistrées", value: "\(store.cards.count)")
                    LabeledContent("Version", value: "2.1.0 (build 21)")
                } header: {
                    Text("Informations")
                } footer: {
                    Text("Toutes tes données restent sur cet appareil. Aucune donnée n'est transmise sur un réseau ou serveur tiers.")
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                }
            }
            // Sheets de mot de passe
            .sheet(isPresented: $showingExportPasswordSheet) {
                EncryptedExportSheet { password in
                    prepareEncryptedExport(password: password)
                }
            }
            .sheet(isPresented: $showingImportPasswordSheet) {
                if let data = pendingImportData {
                    EncryptedImportSheet { password in
                        performEncryptedImport(data: data, password: password)
                    }
                }
            }
            // File Exporters
            .fileExporter(
                isPresented: $showingEncryptedExporter,
                document: encryptedExportDoc,
                contentType: .stashBackup,
                defaultFilename: defaultBackupFilename
            ) { result in
                switch result {
                case .success:
                    show("Sauvegarde chiffrée exportée avec succès.", isError: false)
                case .failure(let error):
                    show("Échec de l'export : \(error.localizedDescription)", isError: true)
                }
            }
            .fileExporter(
                isPresented: $showingPlainExporter,
                document: plainExportDoc,
                contentType: .json,
                defaultFilename: "stash-export"
            ) { result in
                switch result {
                case .success:
                    show("Export JSON créé avec succès.", isError: false)
                case .failure(let error):
                    show("Échec de l'export : \(error.localizedDescription)", isError: true)
                }
            }
            // File Importer (pour restauration)
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.stashBackup, .json, .data]
            ) { result in
                handleFileImport(result)
            }
            // Folder Picker (pour sauvegarde auto)
            .fileImporter(
                isPresented: $showingFolderPicker,
                allowedContentTypes: [.folder]
            ) { result in
                handleFolderSelection(result)
            }
        }
    }

    // MARK: - Actions

    private var defaultBackupFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "stash-backup-\(formatter.string(from: Date()))"
    }

    private func prepareEncryptedExport(password: String) {
        do {
            let data = try store.exportEncryptedBackup(password: password)
            encryptedExportDoc = StashBackupDocument(data: data)
            showingEncryptedExporter = true
        } catch {
            show("Erreur de chiffrement : \(error.localizedDescription)", isError: true)
        }
    }

    private func preparePlainExport() {
        guard let data = store.exportData() else {
            show("Impossible de préparer l'export JSON.", isError: true)
            return
        }
        plainExportDoc = BackupDocument(data: data)
        showingPlainExporter = true
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let needsRelease = url.startAccessingSecurityScopedResource()
            defer { if needsRelease { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                // Vérifier si c'est une archive chiffrée Stash (header magique ou extension)
                let isEncrypted = data.starts(with: BackupService.magicHeader) || url.pathExtension.lowercased() == "stashbackup"

                if isEncrypted {
                    pendingImportData = data
                    showingImportPasswordSheet = true
                } else {
                    // Import JSON classique
                    if let count = store.importData(data) {
                        show("\(count) carte(s) importée(s) depuis l'archive JSON.", isError: false)
                    } else {
                        show("Format de fichier non reconnu ou corrompu.", isError: true)
                    }
                }
            } catch {
                show("Échec de lecture : \(error.localizedDescription)", isError: true)
            }
        case .failure(let error):
            show("Import annulé : \(error.localizedDescription)", isError: true)
        }
    }

    private func performEncryptedImport(data: Data, password: String) {
        do {
            let count = try store.importEncryptedBackup(data, password: password)
            pendingImportData = nil
            show("\(count) carte(s) restaurée(s) avec succès (secrets Keychain restaurés).", isError: false)
        } catch {
            show("Échec de restauration : \(error.localizedDescription)", isError: true)
        }
    }

    private func handleFolderSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let folderURL):
            if AutoBackupService.configureFolder(url: folderURL) {
                autoBackupFolder = AutoBackupService.folderName ?? folderURL.lastPathComponent
                AutoBackupService.performAutoBackup(cards: store.cards)
                show("Sauvegarde automatique configurée dans « \(autoBackupFolder ?? "") »", isError: false)
            } else {
                show("Impossible d'accéder au dossier sélectionné.", isError: true)
            }
        case .failure(let error):
            show("Sélection annulée : \(error.localizedDescription)", isError: true)
        }
    }

    private func show(_ text: String, isError: Bool) {
        message = text
        messageIsError = isError
    }
}

// MARK: - Modales de mot de passe

private struct EncryptedExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onConfirm: (String) -> Void

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?

    private var isValid: Bool {
        !password.isEmpty && password == confirmPassword && password.count >= 6
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Protection maximale", systemImage: "shield.lefthalf.filled")
                            .font(.headline)
                            .foregroundStyle(.blue)
                        Text("Définis un mot de passe pour chiffrer l'ensemble de tes cartes et numéros secrets avec AES-256-GCM.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    SecureField("Mot de passe (6 caractères min.)", text: $password)
                    SecureField("Confirmer le mot de passe", text: $confirmPassword)
                } header: {
                    Text("Mot de passe de sauvegarde")
                } footer: {
                    if !password.isEmpty && password.count < 6 {
                        Text("Le mot de passe doit comporter au moins 6 caractères.")
                            .foregroundStyle(.red)
                    } else if !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Les mots de passe ne correspondent pas.")
                            .foregroundStyle(.red)
                    } else {
                        Text("⚠️ Ce mot de passe sera indispensable pour restaurer vos cartes. Il ne pourra jamais être réinitialisé en cas d'oubli.")
                    }
                }
            }
            .navigationTitle("Chiffrer la sauvegarde")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Exporter") {
                        dismiss()
                        onConfirm(password)
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct EncryptedImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onConfirm: (String) -> Void

    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Sauvegarde chiffrée", systemImage: "lock.fill")
                            .font(.headline)
                            .foregroundStyle(.blue)
                        Text("Saisis le mot de passe défini lors de la création de cette archive pour déchiffrer tes cartes et restaurer les secrets.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    SecureField("Mot de passe de déchiffrement", text: $password)
                }
            }
            .navigationTitle("Déchiffrer l'archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Restaurer") {
                        dismiss()
                        onConfirm(password)
                    }
                    .disabled(password.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Documents pour FileExporter

/// Document binaire .stashbackup chiffré
struct StashBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.stashBackup, .data] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Document JSON exporté
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
