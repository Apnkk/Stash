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

    @State private var showDeleteConfirm = false

    private var isEditing: Bool { card != nil }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch kind {
        case .loyalty:
            return !code.trimmingCharacters(in: .whitespaces).isEmpty
        case .bank:
            // À la création il faut un numéro ; en édition on peut le laisser inchangé.
            return isEditing || fullNumber.filter(\.isNumber).count >= 12
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
            TextField(isEditing ? "Laisser vide pour ne pas changer" : "Numéro de carte", text: $fullNumber)
                .keyboardType(.numberPad)
            TextField("Titulaire", text: $holder)
                .textInputAutocapitalization(.words)
            TextField("Expiration (MM/AA)", text: $expiry)
                .keyboardType(.numbersAndPunctuation)
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
        // On ne pré-remplit jamais le numéro complet : il reste dans le Keychain.
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

        let number = fullNumber.isEmpty ? nil : fullNumber
        store.upsert(updated, fullNumber: number)
        dismiss()
    }
}
