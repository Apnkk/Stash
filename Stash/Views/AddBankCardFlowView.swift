import SwiftUI

/// Flux d'ajout d'une carte bancaire, façon Apple Wallet : plein écran, une
/// étape à la fois, avec un aperçu de carte réaliste toujours visible en haut
/// qui se construit sous les yeux de l'utilisateur au fil de la saisie.
///
/// Réservé à la CRÉATION d'une carte bancaire. L'édition et les autres types
/// de cartes continuent d'utiliser `CardFormView`.
struct AddBankCardFlowView: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss

    /// Étapes du flux, dans l'ordre. `CaseIterable` sert à connaître la
    /// progression et à savoir quelle est la dernière étape.
    private enum Step: Int, CaseIterable {
        case number
        case holder
        case expiry
        case design
        case review

        var title: String {
            switch self {
            case .number: return "Numéro de carte"
            case .holder: return "Titulaire"
            case .expiry: return "Expiration"
            case .design: return "Design"
            case .review: return "Récapitulatif"
            }
        }

        var subtitle: String {
            switch self {
            case .number: return "Saisis le numéro à 16 chiffres inscrit sur ta carte."
            case .holder: return "Le nom tel qu'il apparaît sur la carte (facultatif)."
            case .expiry: return "La date d'expiration au format MM/AA (facultatif)."
            case .design: return "Choisis un réseau et une couleur, ou laisse l'automatique."
            case .review: return "Vérifie les informations avant d'enregistrer."
            }
        }
    }

    // MARK: - État de saisie

    @State private var step: Step = .number

    @State private var fullNumber = ""
    @State private var holder = ""
    @State private var expiry = ""
    @State private var name = ""
    @State private var colorHex = Palette.colors[0]
    @State private var manualNetwork: CardNetwork = .unknown
    @State private var designID = ""
    @State private var showingDesignPicker = false

    @State private var saveError: String?
    @State private var showingScanner = false
    /// Non-nil après un enregistrement réussi : déclenche l'écran de succès.
    @State private var savedCardName: String?

    /// Contrôle la direction de la transition entre étapes (avance / recule).
    @State private var isGoingForward = true

    /// Champ actuellement au clavier, pour donner le focus automatiquement à
    /// chaque étape (comme Apple Wallet).
    @FocusState private var focusedField: Field?

    /// Champs susceptibles de recevoir le focus clavier.
    private enum Field: Hashable {
        case number
        case holder
        case expiry
        case name
    }

    // MARK: - Valeurs dérivées

    private var detectedNetwork: CardNetwork {
        CardNetwork.detect(from: fullNumber)
    }

    private var numberValidation: CardValidator.Result {
        CardValidator.validate(fullNumber)
    }

    private var numberDigits: String {
        fullNumber.filter(\.isNumber)
    }

    /// Le numéro saisi est-il complet et valide (Luhn + longueur + réseau) ?
    private var numberIsValid: Bool {
        numberValidation.isValid
    }

    private var expiryIsValid: Bool {
        expiry.isEmpty || CardValidator.isExpiryValid(expiry)
    }

    /// Le nom de la carte est-il renseigné (obligatoire) ?
    private var nameIsValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Nom effectif de la carte : le nom saisi (obligatoire à l'étape Design),
    /// avec un repli lisible utilisé UNIQUEMENT pour l'aperçu et le récap tant
    /// que l'utilisateur n'a pas encore tapé de nom.
    private var effectiveName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        let last = String(numberDigits.suffix(4))
        let net = effectiveNetwork
        if net != .unknown && !last.isEmpty {
            return "\(net.label) •••• \(last)"
        }
        if !last.isEmpty { return "Carte •••• \(last)" }
        return "Carte bancaire"
    }

    /// Réseau utilisé pour l'apparence : choix manuel prioritaire, sinon détecté.
    private var effectiveNetwork: CardNetwork {
        manualNetwork != .unknown ? manualNetwork : detectedNetwork
    }

    /// L'utilisateur peut-il passer à l'étape suivante depuis l'étape courante ?
    private var canAdvance: Bool {
        switch step {
        case .number: return numberIsValid
        case .holder: return true
        case .expiry: return expiryIsValid
        case .design: return nameIsValid
        case .review: return nameIsValid
        }
    }

    /// Carte reconstruite en direct depuis la saisie, pour l'aperçu.
    private var previewCard: Card {
        var c = Card(kind: .bank, name: effectiveName)
        c.colorHex = colorHex
        c.holder = holder
        c.expiry = expiry
        if !numberDigits.isEmpty {
            let brand = BINDatabase.brandInfo(for: numberDigits)
            c.lastFour = String(numberDigits.suffix(4))
            c.networkRaw = detectedNetwork.rawValue
            c.bankName = brand.bankName ?? ""
            c.bankColorHex = brand.brandColors?.first ?? ""
        }
        c.manualNetworkRaw = manualNetwork == .unknown ? "" : manualNetwork.rawValue
        c.designID = designID
        return c
    }

    // MARK: - Corps

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        RealisticCardView(
                            card: previewCard,
                            revealedNumber: numberDigits.isEmpty ? nil : numberDigits
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .animation(Motion.snappy, value: colorHex)
                        .animation(Motion.snappy, value: manualNetwork)
                        .animation(Motion.snappy, value: numberDigits)

                        stepHeader

                        stepContent
                            .padding(.horizontal, 20)
                            .id(step)
                            .transition(stepTransition)

                        if let saveError {
                            Text(saveError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.bottom, 24)
                }

                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .navigationTitle("Nouvelle carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                // Bouton « OK » pour replier le clavier numérique (pas de touche
                // retour sur .numberPad).
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { focusedField = nil }
                }
            }
            .onAppear { focusField(for: step) }
            .onChange(of: step) { _, newStep in
                focusField(for: newStep)
            }
        }
        // Écran de célébration par-dessus le flux ; sa fermeture enchaîne sur
        // le dismiss habituel (retour à l'accueil + mise en avant).
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
        .sheet(isPresented: $showingScanner) {
            ScannerView(
                mode: .bankCard,
                onBankCardScanned: { number, exp in
                    self.fullNumber = formatCardNumber(number)
                    if let exp { self.expiry = exp }
                }
            )
        }
        .sheet(isPresented: $showingDesignPicker) {
            DesignPickerView(selectedDesignID: $designID)
        }
    }

    // MARK: - Barre de progression

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.stashRed : Color.secondary.opacity(0.2))
                    .frame(height: 4)
                    .animation(Motion.snappy, value: step)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Étape \(step.rawValue + 1) sur \(Step.allCases.count) : \(step.title)")
    }

    // MARK: - En-tête d'étape

    private var stepHeader: some View {
        VStack(spacing: 6) {
            Text(step.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text(step.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .id("header-\(step.rawValue)")
        .transition(.opacity)
    }

    // MARK: - Contenu par étape

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .number: numberStep
        case .holder: holderStep
        case .expiry: expiryStep
        case .design: designStep
        case .review: reviewStep
        }
    }

    private var numberStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("1234 5678 9012 3456", text: $fullNumber)
                    .keyboardType(.numberPad)
                    .font(.title3.monospaced())
                    .textContentType(.creditCardNumber)
                    .focused($focusedField, equals: .number)
                    .onChange(of: fullNumber) { _, newValue in
                        fullNumber = formatCardNumber(newValue)
                    }
                if !numberDigits.isEmpty && detectedNetwork != .unknown {
                    Text(detectedNetwork.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.15), in: Capsule())
                        .transition(.popIn)
                        .accessibilityLabel("Réseau détecté : \(detectedNetwork.label)")
                }

                Button {
                    Haptics.light()
                    showingScanner = true
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.stashRed)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Scanner la carte bancaire")
            }
            .padding(14)
            .glassPanel(cornerRadius: 14)

            Button {
                Haptics.light()
                showingScanner = true
            } label: {
                Label("Scanner ma carte", systemImage: "camera.viewfinder")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.stashRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Color.stashRed)
            }
            .buttonStyle(.plain)

            if !numberDigits.isEmpty && !numberIsValid {
                Text("Numéro incomplet ou invalide (vérifie les chiffres).")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .animation(Motion.snappy, value: detectedNetwork)
        .animation(Motion.snappy, value: numberIsValid)
    }

    private var holderStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Nom du titulaire", text: $holder)
                .textInputAutocapitalization(.words)
                .textContentType(.name)
                .font(.title3)
                .focused($focusedField, equals: .holder)
                .padding(14)
                .glassPanel(cornerRadius: 14)
        }
    }

    private var expiryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("MM/AA", text: $expiry)
                .keyboardType(.numbersAndPunctuation)
                .font(.title3.monospaced())
                .focused($focusedField, equals: .expiry)
                .padding(14)
                .glassPanel(cornerRadius: 14)
                .onChange(of: expiry) { _, newValue in
                    expiry = formatExpiry(newValue)
                }

            if !expiryIsValid {
                Text("Date d'expiration invalide ou dépassée.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .animation(Motion.snappy, value: expiryIsValid)
    }

    private var designStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Réseau")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("Réseau", selection: $manualNetwork) {
                    Text("Automatique").tag(CardNetwork.unknown)
                    ForEach(CardNetwork.selectable) { net in
                        Text(net.label).tag(net)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Nom de la carte")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Ex. Visa perso, Compte joint…", text: $name)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .name)
                    .padding(14)
                    .glassPanel(cornerRadius: 14)

                if !nameIsValid {
                    Text("Donne un nom à ta carte pour la retrouver facilement.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Visuel de la carte")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button {
                    Haptics.light()
                    showingDesignPicker = true
                } label: {
                    HStack(spacing: 12) {
                        if let design = CardDesign.find(designID) {
                            design.image
                                .resizable()
                                .aspectRatio(1.585, contentMode: .fit)
                                .frame(width: 44, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(design.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Design officiel Stash")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Couleur unie")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Choisir parmi les 17 designs intégrés")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text("Changer")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.stashRed)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .glassPanel(cornerRadius: 14)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Couleur de secours")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                colorPicker
            }
        }
        .animation(Motion.snappy, value: manualNetwork)
        .animation(Motion.snappy, value: nameIsValid)
    }

    private var reviewStep: some View {
        VStack(spacing: 12) {
            reviewRow("Nom", effectiveName)
            reviewRow("Réseau", effectiveNetwork == .unknown ? "Automatique" : effectiveNetwork.label)
            reviewRow("Numéro", "•••• •••• •••• \(String(numberDigits.suffix(4)))")
            reviewRow("Titulaire", holder.isEmpty ? "—" : holder)
            reviewRow("Expiration", expiry.isEmpty ? "—" : expiry)
        }
        .padding(16)
        .glassPanel(cornerRadius: 16)
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Sélecteur de couleur

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

    // MARK: - Pied de page (navigation entre étapes)

    private var footer: some View {
        HStack(spacing: 12) {
            if step != .number {
                Button {
                    goBack()
                } label: {
                    Label("Retour", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .glassButtonIfAvailable()
            }

            Button {
                if step == .review {
                    save()
                } else {
                    goNext()
                }
            } label: {
                Text(step == .review ? "Enregistrer" : "Continuer")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .glassProminentButtonIfAvailable()
            .disabled(!canAdvance)
        }
    }

    // MARK: - Transitions

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isGoingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isGoingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: - Navigation

    private func goNext() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        Haptics.light()
        isGoingForward = true
        withAnimation(Motion.standard) { step = next }
    }

    private func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        Haptics.light()
        isGoingForward = false
        withAnimation(Motion.standard) { step = previous }
    }

    // MARK: - Focus clavier

    /// Donne le focus au champ pertinent pour l'étape, ou replie le clavier
    /// sur les étapes sans saisie (design/récapitulatif).
    private func focusField(for step: Step) {
        switch step {
        case .number: focusedField = .number
        case .holder: focusedField = .holder
        case .expiry: focusedField = .expiry
        case .design, .review: focusedField = nil
        }
    }

    // MARK: - Formatage

    /// Formate la saisie du numéro en blocs séparés par des espaces, selon le
    /// réseau détecté (4-6-5 pour Amex, 4-4-4-4… sinon), et borne la longueur
    /// à la plus grande longueur valide du réseau. Réutilise `grouped` via les
    /// tailles de blocs de `CardNetwork`.
    private func formatCardNumber(_ input: String) -> String {
        var digits = input.filter(\.isNumber)
        let network = CardNetwork.detect(from: digits)
        // Longueur maximale autorisée pour ce réseau (19 par défaut).
        let maxLength = network.validLengths.max() ?? 19
        if digits.count > maxLength {
            digits = String(digits.prefix(maxLength))
        }
        return groupNumber(digits, sizes: network.groupSizes)
    }

    /// Regroupe les chiffres selon les tailles de blocs du réseau ; le reste
    /// éventuel (numéros à 19 chiffres) est ajouté par blocs de 4.
    private func groupNumber(_ digits: String, sizes: [Int]) -> String {
        guard !digits.isEmpty else { return "" }
        var groups: [String] = []
        var index = digits.startIndex
        for size in sizes {
            guard index < digits.endIndex else { break }
            let end = digits.index(index, offsetBy: size, limitedBy: digits.endIndex) ?? digits.endIndex
            groups.append(String(digits[index..<end]))
            index = end
        }
        while index < digits.endIndex {
            let end = digits.index(index, offsetBy: 4, limitedBy: digits.endIndex) ?? digits.endIndex
            groups.append(String(digits[index..<end]))
            index = end
        }
        return groups.joined(separator: " ")
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

    // MARK: - Enregistrement

    private func save() {
        var card = Card(kind: .bank, name: effectiveName)
        card.colorHex = colorHex
        card.holder = holder.trimmingCharacters(in: .whitespaces)
        card.expiry = expiry.trimmingCharacters(in: .whitespaces)

        let brand = BINDatabase.brandInfo(for: numberDigits)
        card.networkRaw = detectedNetwork.rawValue
        card.bankName = brand.bankName ?? ""
        card.bankColorHex = brand.brandColors?.first ?? ""
        card.manualNetworkRaw = manualNetwork == .unknown ? "" : manualNetwork.rawValue
        card.designID = designID

        do {
            try store.upsert(card, fullNumber: fullNumber)
            withAnimation(Motion.standard) {
                savedCardName = card.name
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
