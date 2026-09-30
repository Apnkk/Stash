import SwiftUI

/// Formulaire d'ajout / modification d'une carte.
struct CardFormView: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss

    /// Carte à modifier, ou `nil` pour une création.
    let card: Card?

    @State private var kind: CardKind = .loyalty
    @State private var name = ""
    @State private var colorHex = Palette.colors[0]

    // Fidélité
    @State private var code = ""
    @State private var format: BarcodeFormat = .auto

    // Bancaire
    @State private var fullNumber = ""
    @State private var holder = ""
    @State private var expiry = ""

    // Commun
    @State private var note = ""

    @State private var showDeleteConfirm = false
    @State private var saveError: String?

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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(CardKind.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isEditing) // on ne change pas le type d'une carte existante

                    TextField("Nom de la carte", text: $name)
                        .textInputAutocapitalization(.words)
                }

                if kind == .loyalty {
                    loyaltySection
                } else {
                    bankSection
                }

                Section("Couleur") {
                    colorPicker
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
            .onAppear(perform: loadIfEditing)
        }
    }

    private var loyaltySection: some View {
        Section("Code de fidélité") {
            TextField("Numéro / code", text: $code)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Picker("Type de code", selection: $format) {
                ForEach(BarcodeFormat.allCases) { Text($0.label).tag($0) }
            }
        }
    }

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
    }

    private var colorPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
            ForEach(Palette.colors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 38, height: 38)
                    .overlay {
                        if hex == colorHex {
                            Circle().strokeBorder(.primary, lineWidth: 3)
                        }
                    }
                    .onTapGesture { colorHex = hex }
                    .accessibilityLabel("Couleur \(hex)")
                    .accessibilityAddTraits(hex == colorHex ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
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
        // On ne pré-remplit jamais le numéro complet : il reste dans le Keychain.
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

        let number = fullNumber.isEmpty ? nil : fullNumber
        do {
            try store.upsert(updated, fullNumber: number)
            dismiss()
        } catch {
            saveError = (error as? LocalizedError)?.errorDescription
                ?? "Impossible d'enregistrer la carte."
        }
    }
}
