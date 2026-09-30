import SwiftUI
import PhotosUI

/// Formulaire d'ajout / modification d'une carte.
///
/// Nouveauté : un aperçu en direct de la carte s'affiche en haut du formulaire
/// et se met à jour au fil de la saisie (nom, couleur, code/numéro), pour que
/// l'utilisateur voie tout de suite le rendu final.
struct CardFormView: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss

    /// Carte à modifier, ou `nil` pour une création.
    let card: Card?

    /// Type imposé à la création (choisi sur l'écran précédent). En édition,
    /// c'est le type de la carte qui prime. `nil` = ancien comportement.
    var presetKind: CardKind? = nil

    @State private var kind: CardKind = .loyalty
    @State private var kindLocked = false
    @State private var name = ""
    @State private var colorHex = Palette.colors[0]

    // Fidélité
    @State private var code = ""
    @State private var format: BarcodeFormat = .auto

    // Bancaire
    @State private var fullNumber = ""
    @State private var holder = ""
    @State private var expiry = ""

    /// Design/réseau choisi manuellement par l'utilisateur. `.unknown` =
    /// « Automatique » (on laisse la détection depuis le numéro décider).
    @State private var manualNetwork: CardNetwork = .unknown

    // Commun
    @State private var note = ""

    // Image de fond ("card art")
    /// Élément choisi dans la photothèque, en attente de chargement en UIImage.
    @State private var artItem: PhotosPickerItem?
    /// Aperçu affiché (image existante chargée à l'édition, ou nouvelle sélection).
    @State private var artPreview: UIImage?
    /// Intention à appliquer au moment de l'enregistrement.
    @State private var artChange: CardStore.ArtChange = .unchanged

    @State private var showDeleteConfirm = false
    @State private var saveError: String?

    /// Non-nil après un enregistrement réussi : déclenche l'écran de succès.
    /// Contient le nom de la carte à afficher dans la célébration.
    @State private var savedCardName: String?

    /// Réseau bancaire déduit en direct du numéro saisi.
    private var detectedNetwork: CardNetwork {
        CardNetwork.detect(from: fullNumber)
    }

    /// Validation type Wallet du numéro saisi (Luhn + longueur + réseau).
    private var numberValidation: CardValidator.Result {
        CardValidator.validate(fullNumber)
    }

    /// Le numéro saisi est-il complet et cohérent ? (vide = neutre, pas d'erreur)
    private var numberLooksValid: Bool {
        fullNumber.filter(\.isNumber).isEmpty || numberValidation.isValid
    }

    /// L'expiration saisie est-elle valide ? (vide = neutre)
    private var expiryLooksValid: Bool {
        expiry.isEmpty || CardValidator.isExpiryValid(expiry)
    }

    private var isEditing: Bool { card != nil }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch kind {
        case .loyalty:
            return !code.trimmingCharacters(in: .whitespaces).isEmpty
        case .other:
            // Pour une « autre carte », le nom suffit ; le code est facultatif.
            return true
        case .bank:
            // L'expiration, si renseignée, doit être valide dans les deux cas.
            guard expiry.isEmpty || CardValidator.isExpiryValid(expiry) else { return false }
            if isEditing {
                // En édition on peut laisser le numéro inchangé (vide) ; s'il est
                // saisi, il doit être valide.
                return fullNumber.filter(\.isNumber).isEmpty || numberValidation.isValid
            }
            // À la création il faut un numéro complet et valide (Luhn + longueur).
            return numberValidation.isValid
        }
    }

    /// Carte reconstruite en direct depuis la saisie, pour l'aperçu.
    private var previewCard: Card {
        var c = card ?? Card(kind: kind, name: name)
        c.kind = kind
        c.name = name
        c.colorHex = colorHex
        c.code = code
        c.format = format
        c.holder = holder
        c.expiry = expiry
        if kind == .bank {
            let digits = fullNumber.filter(\.isNumber)
            if !digits.isEmpty {
                let brand = BINDatabase.brandInfo(for: digits)
                c.lastFour = String(digits.suffix(4))
                c.networkRaw = CardNetwork.detect(from: digits).rawValue
                c.bankName = brand.bankName ?? ""
                c.bankColorHex = brand.brandColors?.first ?? ""
            }
            c.manualNetworkRaw = manualNetwork == .unknown ? "" : manualNetwork.rawValue
        }
        return c
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    livePreview
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                }

                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(CardKind.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    // On ne change pas le type d'une carte existante, ni celui
                    // choisi sur l'écran de sélection précédent.
                    .disabled(isEditing || kindLocked)

                    TextField("Nom de la carte", text: $name)
                        .textInputAutocapitalization(.words)
                }

                if kind == .bank {
                    bankSection
                } else {
                    loyaltySection
                }

                Section("Couleur") {
                    colorPicker
                }

                Section {
                    artPickerRow
                } header: {
                    Text("Image de fond")
                } footer: {
                    Text("Personnalise la carte avec une photo. Elle reste sur ton téléphone, hors sauvegarde iCloud.")
                }

                Section {
                    TextField("Note (facultatif)", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                } header: {
                    Text("Note")
                } footer: {
                    Text("Visible seulement dans l'app, stockée sur ton téléphone.")
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Supprimer la carte", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifier" : "Nouvelle carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(!canSave)
                        .glassProminentButtonIfAvailable()
                }
            }
            .confirmationDialog("Supprimer cette carte ?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    if let card { store.delete(card); dismiss() }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Cette action est définitive.")
            }
            .onAppear(perform: configureOnAppear)
        }
        // Écran de célébration par-dessus le formulaire ; sa fermeture
        // enchaîne sur le dismiss habituel (retour à l'accueil + mise en avant).
        .overlay {
            if let savedCardName {
                CardSavedSuccessView(cardName: savedCardName) {
                    dismiss()
                }
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .animation(Motion.standard, value: savedCardName != nil)
    }

    /// Aperçu en direct : mini-carte bancaire réaliste, ou tuile pour les autres
    /// types, qui reflète immédiatement le nom, la couleur et le code saisis.
    private var livePreview: some View {
        VStack(spacing: 10) {
            Group {
                if kind == .bank {
                    RealisticCardView(card: previewCard, revealedNumber: nil, artOverride: artPreview)
                } else {
                    CardPreviewTile(card: previewCard, artOverride: artPreview)
                }
            }
            .animation(Motion.snappy, value: colorHex)
            .animation(Motion.snappy, value: kind)

            Text("Aperçu")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var loyaltySection: some View {
        Section {
            TextField(kind == .other ? "Numéro / code (facultatif)" : "Numéro / code", text: $code)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Picker("Type de code", selection: $format) {
                ForEach(BarcodeFormat.allCases) { Text($0.label).tag($0) }
            }
        } header: {
            Text(kind == .other ? "Code (facultatif)" : "Code de fidélité")
        } footer: {
            Text(kind == .other
                 ? "Ajoute un code-barres ou QR si la carte en a un. Sinon, laisse vide."
                 : "Le code sera affiché en grand et scannable en caisse.")
        }
    }

    @ViewBuilder
    private var bankSection: some View {
        Section {
            HStack {
                TextField(isEditing ? "Laisser vide pour ne pas changer" : "Numéro de carte", text: $fullNumber)
                    .keyboardType(.numberPad)
                if !fullNumber.isEmpty && detectedNetwork != .unknown {
                    Text(detectedNetwork.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.15), in: Capsule())
                        .accessibilityLabel("Réseau détecté : \(detectedNetwork.label)")
                }
            }
            if !numberLooksValid {
                Text("Numéro de carte invalide (vérifie les chiffres).")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            TextField("Titulaire", text: $holder)
                .textInputAutocapitalization(.words)
            TextField("Expiration (MM/AA)", text: $expiry)
                .keyboardType(.numbersAndPunctuation)
                .onChange(of: expiry) { _, newValue in
                    expiry = formatExpiry(newValue)
                }
            if !expiryLooksValid {
                Text("Date d'expiration invalide ou dépassée.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Carte bancaire")
        } footer: {
            Text("Le numéro complet est chiffré dans le trousseau (Keychain) et n'est jamais envoyé sur un serveur. Il reste masqué et n'est révélé qu'après Face ID / Touch ID.")
        }

        Section {
            networkDesignPicker
        } header: {
            Text("Design de la carte")
        } footer: {
            Text("« Automatique » utilise le réseau détecté depuis le numéro. Choisis un réseau pour forcer le logo et les couleurs affichés.")
        }
    }

    /// Choix manuel du design de réseau (Visa/Mastercard/Amex/Discover), ou
    /// « Automatique » pour laisser la détection depuis le numéro décider.
    private var networkDesignPicker: some View {
        Picker("Réseau", selection: $manualNetwork) {
            Text("Automatique").tag(CardNetwork.unknown)
            ForEach(CardNetwork.selectable) { net in
                Text(net.label).tag(net)
            }
        }
    }

    private var colorPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
            ForEach(Palette.colors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 38, height: 38)
                    .overlay {
                        if hex == colorHex {
                            ZStack {
                                Circle().strokeBorder(Color.white, lineWidth: 2.5)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white)
                            }
                            .transition(.popIn)
                        }
                    }
                    .scaleEffect(hex == colorHex ? 1.1 : 1)
                    .onTapGesture {
                        Haptics.selection()
                        withAnimation(Motion.snappy) { colorHex = hex }
                    }
                    .accessibilityLabel("Couleur \(hex)")
                    .accessibilityAddTraits(hex == colorHex ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    /// Ligne de la section « Image de fond » : aperçu (si présent), bouton de
    /// choix via la photothèque, et bouton de retrait le cas échéant.
    @ViewBuilder
    private var artPickerRow: some View {
        if let artPreview {
            HStack(spacing: 12) {
                Image(uiImage: artPreview)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 66, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .accessibilityLabel("Aperçu de l'image de fond")

                Text("Image sélectionnée")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(role: .destructive) {
                    Haptics.light()
                    withAnimation(Motion.snappy) {
                        self.artPreview = nil
                        self.artItem = nil
                        self.artChange = .remove
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Retirer l'image de fond")
            }
        }

        PhotosPicker(
            selection: $artItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label(
                artPreview == nil ? "Choisir une image" : "Changer l'image",
                systemImage: "photo"
            )
        }
        .onChange(of: artItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadPickedArt(newItem) }
        }
    }

    /// Charge l'image sélectionnée dans la photothèque en `UIImage`, met à jour
    /// l'aperçu et enregistre l'intention `.set` pour la sauvegarde.
    @MainActor
    private func loadPickedArt(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            withAnimation(Motion.snappy) {
                saveError = "Impossible de charger l'image choisie."
            }
            return
        }
        withAnimation(Motion.snappy) {
            artPreview = image
            artChange = .set(image)
        }
    }

    /// Configure le formulaire à l'apparition : type imposé pour une création,
    /// ou chargement des champs pour une édition.
    private func configureOnAppear() {
        if card == nil, let presetKind {
            kind = presetKind
            kindLocked = true
        }
        loadIfEditing()
    }

    private func loadIfEditing() {
        guard let card else { return }
        kind = card.kind
        name = card.name
        colorHex = card.colorHex
        code = card.code
        format = card.format
        holder = card.holder
        expiry = card.expiry
        note = card.note
        // Choix de design manuel déjà enregistré ("" -> Automatique).
        manualNetwork = CardNetwork(rawValue: card.manualNetworkRaw) ?? .unknown
        // On ne pré-remplit jamais le numéro complet : il reste dans le Keychain.

        // Image de fond existante : on la charge pour l'aperçu, sans changer
        // l'intention (elle reste `.unchanged` tant que l'utilisateur n'agit pas).
        if card.hasCustomArt {
            artPreview = ArtVault.load(card.id.uuidString)
        }
    }

    /// Formate la saisie d'expiration en MM/AA au fil de la frappe.
    private func formatExpiry(_ input: String) -> String {
        let digits = String(input.filter(\.isNumber).prefix(4))
        guard !digits.isEmpty else { return "" }
        if digits.count <= 2 { return digits }
        let month = digits.prefix(2)
        let year = digits.dropFirst(2)
        return "\(month)/\(year)"
    }

    private func save() {
        let base = card ?? Card(kind: kind, name: name)
        var updated = base
        updated.kind = kind
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.colorHex = colorHex
        updated.code = code.trimmingCharacters(in: .whitespaces)
        updated.format = format
        updated.holder = holder.trimmingCharacters(in: .whitespaces)
        updated.expiry = expiry.trimmingCharacters(in: .whitespaces)
        updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fige la marque (réseau + banque) tant que le numéro complet est en
        // clair ici. Ces champs ne sont PAS sensibles et évitent de relire le
        // Keychain à l'accueil. En édition sans nouveau numéro, on conserve la
        // marque déjà enregistrée.
        if kind == .bank {
            let digits = fullNumber.filter(\.isNumber)
            if !digits.isEmpty {
                let brand = BINDatabase.brandInfo(for: digits)
                updated.networkRaw = CardNetwork.detect(from: digits).rawValue
                updated.bankName = brand.bankName ?? ""
                updated.bankColorHex = brand.brandColors?.first ?? ""
            }
            // Choix de design manuel : "" = Automatique (on laisse networkRaw décider).
            updated.manualNetworkRaw = manualNetwork == .unknown ? "" : manualNetwork.rawValue
        } else {
            updated.networkRaw = ""
            updated.manualNetworkRaw = ""
            updated.bankName = ""
            updated.bankColorHex = ""
        }

        let number = fullNumber.isEmpty ? nil : fullNumber
        do {
            try store.upsert(updated, fullNumber: number, art: artChange)
            // On n'appelle plus dismiss() ici : à la création, on montre
            // d'abord l'écran de succès, qui fera le dismiss à la fin. En
            // édition, on ferme directement (pas de célébration nécessaire).
            if isEditing {
                Haptics.success()
                dismiss()
            } else {
                withAnimation(Motion.standard) {
                    savedCardName = updated.name
                }
            }
        } catch {
            Haptics.error()
            withAnimation(Motion.snappy) {
                saveError = (error as? LocalizedError)?.errorDescription
                    ?? "Impossible d'enregistrer la carte."
            }
        }
    }
}

/// Aperçu compact d'une carte de fidélité / autre, réutilisant le style visuel
/// de la tuile d'accueil sans dépendre de l'état de surlignage.
private struct CardPreviewTile: View {
    let card: Card
    /// Image de fond à afficher en aperçu direct (avant enregistrement).
    var artOverride: UIImage? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: card.kind == .other ? "rectangle.stack.fill" : "barcode")
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(card.kind.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.18), in: Capsule())
            }

            Spacer()

            Text(card.name.isEmpty ? "Nom de la carte" : card.name)
                .font(.headline)
                .foregroundStyle(card.name.isEmpty ? Color.white.opacity(0.5) : Color.white)
                .lineLimit(1)

            Text(subtitle)
                .font(.subheadline.monospaced())
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
        .padding(18)
        .frame(height: 130)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if let artOverride {
                Image(uiImage: artOverride)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        // Voile sombre pour garder le texte lisible sur toute image.
                        LinearGradient(
                            colors: [.black.opacity(0.15), .black.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                LinearGradient(
                    colors: [Color(hex: card.colorHex), Color(hex: card.colorHex).opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }

    private var subtitle: String {
        switch card.kind {
        case .loyalty:
            return card.code.isEmpty ? "Numéro / code" : card.code
        case .other:
            return card.code.isEmpty ? "Carte" : card.code
        case .bank:
            return "•••• \(card.lastFour.isEmpty ? "••••" : card.lastFour)"
        }
    }
}
