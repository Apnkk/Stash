import SwiftUI
import UniformTypeIdentifiers

/// Écran Réglages : sauvegarde (export) et restauration (import) des cartes.
///
/// Seules les métadonnées visibles sont exportées (nom, couleur, code de
/// fidélité, 4 derniers chiffres, note…). Les numéros de carte bancaire
/// complets restent dans le Keychain et ne quittent JAMAIS l'appareil.
struct SettingsView: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportDocument: BackupDocument?
    @State private var message: String?
    @State private var messageIsError = false

    @AppStorage(AutoLockDelay.storageKey) private var autoLockRaw = AutoLockDelay.thirtySeconds.rawValue
    @AppStorage(ExpiryReminderService.settingsKey) private var expiryRemindersEnabled = false

    var body: some View {
        NavigationStack {
            Form {
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

                Section {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Exporter mes cartes", systemImage: "square.and.arrow.up")
                    }
                    .disabled(store.cards.isEmpty)

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Importer une sauvegarde", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Sauvegarde")
                } footer: {
                    Text("La sauvegarde contient tes cartes (nom, couleur, code de fidélité, note, 4 derniers chiffres). Les numéros de carte bancaire complets restent chiffrés dans le trousseau et ne sont jamais exportés.")
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(messageIsError ? .red : .green)
                    }
                }

                Section {
                    LabeledContent("Cartes enregistrées", value: "\(store.cards.count)")
                } header: {
                    Text("Informations")
                } footer: {
                    Text("Toutes tes données restent sur cet appareil. Aucune donnée n'est envoyée sur un serveur. Le paiement sans contact (NFC) n'est pas disponible : Apple le réserve à Apple Pay.")
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "stash-backup"
            ) { result in
                switch result {
                case .success:
                    show("Sauvegarde exportée.", isError: false)
                case .failure(let error):
                    show("Échec de l'export : \(error.localizedDescription)", isError: true)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json]
            ) { result in
                handleImport(result)
            }
        }
    }

    private func prepareExport() {
        guard let data = store.exportData() else {
            show("Impossible de préparer la sauvegarde.", isError: true)
            return
        }
        exportDocument = BackupDocument(data: data)
        showingExporter = true
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let needsRelease = url.startAccessingSecurityScopedResource()
            defer { if needsRelease { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                if let count = store.importData(data) {
                    show("\(count) carte(s) importée(s).", isError: false)
                } else {
                    show("Fichier de sauvegarde invalide.", isError: true)
                }
            } catch {
                show("Échec de la lecture : \(error.localizedDescription)", isError: true)
            }
        case .failure(let error):
            show("Import annulé : \(error.localizedDescription)", isError: true)
        }
    }

    private func show(_ text: String, isError: Bool) {
        message = text
        messageIsError = isError
    }
}

/// Document JSON transporté par `fileExporter`.
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
