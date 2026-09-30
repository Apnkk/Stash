import SwiftUI
import UIKit
import Combine

/// Vue plein écran d'une carte.
/// - Fidélité : affiche le code-barres / QR en grand pour le scan en caisse.
/// - Bancaire : numéro masqué, révélé et copiable après Face ID / Touch ID.
struct CardDetailView: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let card: Card

    @State private var showingEdit = false
    @State private var revealedNumber: String?
    @State private var authError: String?
    @State private var copied = false
    @State private var codeCopied = false
    @State private var shareImage: UIImage?
    @State private var showingShare = false
    @State private var isCaptured = UIScreen.main.isCaptured

    /// Tâche d'auto-masquage : re-masque le numéro après un délai d'inactivité.
    @State private var autoHideTask: Task<Void, Never>?

    /// Délai avant re-masquage automatique du numéro révélé (secondes).
    private let autoHideDelay: UInt64 = 30

    // Sauvegarde/restaure la luminosité pour un scan plus fiable (fidélité).
    @State private var previousBrightness = UIScreen.main.brightness

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                if card.kind == .loyalty {
                    loyaltyContent
                } else {
                    bankContent
                }

                if !currentCard.note.isEmpty {
                    noteSection
                }
            }
            .padding(20)
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Modifier") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            CardFormView(card: currentCard)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingShare) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
        .onAppear {
            if card.kind == .loyalty {
                previousBrightness = UIScreen.main.brightness
                UIScreen.main.brightness = 1.0
            }
        }
        .onDisappear {
            if card.kind == .loyalty {
                UIScreen.main.brightness = previousBrightness
            }
            autoHideTask?.cancel()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Confidentialité : dès que l'app quitte le premier plan (feuille
            // de partage, sélecteur multitâche, verrouillage…), on re-masque
            // le numéro bancaire pour qu'il n'apparaisse pas dans l'aperçu
            // multitâche ni sur une capture d'écran système.
            if newPhase != .active, revealedNumber != nil {
                hide()
            }
        }
        // Anti-capture : re-masque immédiatement le numéro si l'utilisateur
        // fait une capture d'écran.
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.userDidTakeScreenshotNotification
        )) { _ in
            if revealedNumber != nil { hide() }
        }
        // Enregistrement d'écran / recopie AirPlay : masque tant que l'écran
        // est capturé, et empêche de révéler pendant ce temps.
        .onReceive(NotificationCenter.default.publisher(
            for: UIScreen.capturedDidChangeNotification
        )) { _ in
            isCaptured = UIScreen.main.isCaptured
            if isCaptured, revealedNumber != nil { hide() }
        }
    }

    /// Renvoie la version à jour de la carte depuis le store (après édition).
    private var currentCard: Card {
        store.cards.first(where: { $0.id == card.id }) ?? card
    }

    private var header: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: card.colorHex), Color(hex: card.colorHex).opacity(0.75)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(height: 90)
            .overlay(
                Text(card.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20),
                alignment: .leading
            )
    }

    // MARK: - Fidélité

    private var loyaltyContent: some View {
        VStack(spacing: 16) {
            if let image = BarcodeGenerator.image(for: currentCard) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .padding(24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        if #available(iOS 26, *) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                        }
                    }
            } else {
                Text("Impossible de générer le code pour cette valeur.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(currentCard.code)
                .font(.title3.weight(.semibold).monospaced())
                .textSelection(.enabled)

            HStack(spacing: 12) {
                Button {
                    copyCode()
                } label: {
                    Label(codeCopied ? "Copié !" : "Copier", systemImage: codeCopied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .glassButtonIfAvailable()

                Button {
                    shareCode()
                } label: {
                    Label("Partager", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .glassButtonIfAvailable()
                .disabled(BarcodeGenerator.image(for: currentCard) == nil)
            }

            Text("Présente ce code au lecteur en caisse.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOTE")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(currentCard.note)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(16)
        .glassPanel(cornerRadius: 14)
    }

    // MARK: - Bancaire

    private var bankContent: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text(displayedNumber)
                    .font(.title2.weight(.semibold).monospaced())
                    .textSelectionEnabled(revealedNumber != nil)

                if !currentCard.holder.isEmpty || !currentCard.expiry.isEmpty {
                    HStack(spacing: 20) {
                        if !currentCard.holder.isEmpty {
                            labelValue("Titulaire", currentCard.holder)
                        }
                        if !currentCard.expiry.isEmpty {
                            labelValue("Expire", currentCard.expiry)
                        }
                    }
                }
            }
            .padding(.vertical, 12)

            if let error = authError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if isCaptured {
                Text("Écran en cours d'enregistrement ou de recopie : l'affichage du numéro est bloqué.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            if revealedNumber == nil {
                Button {
                    reveal()
                } label: {
                    Label("Afficher le numéro", systemImage: "eye")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .glassProminentButtonIfAvailable()
                .disabled(isCaptured)
            } else {
                HStack(spacing: 12) {
                    Button {
                        hide()
                    } label: {
                        Label("Masquer", systemImage: "eye.slash")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .glassButtonIfAvailable()

                    Button {
                        copyNumber()
                    } label: {
                        Label(copied ? "Copié !" : "Copier", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .glassProminentButtonIfAvailable()
                }
            }

            Text("Le sans-contact n'est pas possible : Apple réserve le paiement NFC à Apple Pay. Cette app stocke et affiche tes cartes de façon sécurisée.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    private func labelValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private var displayedNumber: String {
        if let number = revealedNumber {
            return formatCardNumber(number)
        }
        let last = currentCard.lastFour.isEmpty ? "••••" : currentCard.lastFour
        return "•••• •••• •••• \(last)"
    }

    /// Regroupe les chiffres par blocs de 4 pour la lisibilité.
    private func formatCardNumber(_ number: String) -> String {
        let digits = number.filter(\.isNumber)
        var result = ""
        for (index, char) in digits.enumerated() {
            if index > 0 && index % 4 == 0 { result += " " }
            result.append(char)
        }
        return result
    }

    private func reveal() {
        authError = nil
        // Enregistrement d'écran actif : on refuse de révéler.
        guard !isCaptured else {
            authError = "Impossible d'afficher pendant un enregistrement d'écran."
            return
        }
        // La lecture du Keychain déclenche elle-même Face ID / Touch ID
        // (SecAccessControl .biometryCurrentSet) : pas de double prompt.
        // On sort du thread principal car SecItemCopyMatching est bloquant.
        // On extrait les valeurs (String, Sendable) sur le MainActor AVANT
        // d'entrer dans le contexte détaché, pour ne pas y capturer `self`
        // ni `store` (isolés @MainActor → erreur de concurrence Swift 6).
        let key = currentCard.id.uuidString
        let reason = "Affiche le numéro de \(currentCard.name)."
        Task {
            do {
                let number = try await Task.detached(priority: .userInitiated) {
                    try SecureVault.read(key, prompt: reason)
                }.value
                await MainActor.run {
                    revealedNumber = number
                    scheduleAutoHide()
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription
                    ?? "Authentification refusée."
                await MainActor.run { authError = message }
            }
        }
    }

    /// Arme (ou ré-arme) le re-masquage automatique après inactivité.
    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = Task {
            try? await Task.sleep(nanoseconds: autoHideDelay * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { hide() }
        }
    }

    private func hide() {
        revealedNumber = nil
        copied = false
        autoHideTask?.cancel()
        autoHideTask = nil
    }

    private func copyNumber() {
        guard let number = revealedNumber else { return }
        UIPasteboard.general.string = number.filter(\.isNumber)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            copied = false
        }
    }

    private func copyCode() {
        UIPasteboard.general.string = currentCard.code
        codeCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            codeCopied = false
        }
    }

    private func shareCode() {
        guard let image = BarcodeGenerator.image(for: currentCard) else { return }
        shareImage = image
        showingShare = true
    }
}

/// Enveloppe UIKit de la feuille de partage système.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private extension View {
    /// Active la sélection de texte de façon conditionnelle.
    /// `.disabled` et `.enabled` étant de types différents, on ne peut pas les
    /// mélanger dans un ternaire : on applique donc le modificateur conditionnellement.
    @ViewBuilder
    func textSelectionEnabled(_ enabled: Bool) -> some View {
        if enabled {
            self.textSelection(.enabled)
        } else {
            self.textSelection(.disabled)
        }
    }
}
