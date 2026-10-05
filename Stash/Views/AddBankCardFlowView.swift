import SwiftUI
import PhotosUI

/// Flux d'ajout d'une carte bancaire inspiré d'Apple Wallet :
/// immersif, respirant, avec prévisualisation 3D réaliste en direct,
/// adaptation fluide au clavier et intégration du CardArt Studio.
struct AddBankCardFlowView: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss

    /// Les 4 étapes du flux optimisé.
    private enum Step: Int, CaseIterable {
        case number
        case details
        case design
        case review

        var title: String {
            switch self {
            case .number:  return "Numéro de carte"
            case .details: return "Détails essentiels"
            case .design:  return "CardArt Studio"
            case .review:  return "Scellé & Sécurité"
            }
        }

        var subtitle: String {
            switch self {
            case .number:  return "Saisis ou scanne les chiffres de ta carte bancaire."
            case .details: return "Date d'expiration, titulaire et nom personnalisé."
            case .design:  return "Choisis un visuel officiel ou importe n'importe quelle carte."
            case .review:  return "Vérifie les informations avant le chiffrement Keychain."
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
    @State private var customArtImage: UIImage? = nil
    @State private var showChip: Bool = true

    @State private var saveError: String?
    @State private var showingScanner = false
    @State private var savedCardName: String?
    @State private var isGoingForward = true

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case number
        case expiry
        case holder
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

    private var numberIsValid: Bool {
        numberValidation.isValid
    }

    private var expiryIsValid: Bool {
        expiry.isEmpty || CardValidator.isExpiryValid(expiry)
    }

    private var detectedBrandInfo: BINDatabase.BrandInfo {
        BINDatabase.brandInfo(for: numberDigits)
    }

    private var effectiveNetwork: CardNetwork {
        manualNetwork != .unknown ? manualNetwork : detectedNetwork
    }

    private var effectiveName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        let bank = detectedBrandInfo.bankName ?? ""
        let last = String(numberDigits.suffix(4))
        let net = effectiveNetwork

        if !bank.isEmpty {
            return last.isEmpty ? bank : "\(bank) •••• \(last)"
        }
        if net != .unknown && !last.isEmpty {
            return "\(net.label) •••• \(last)"
        }
        if !last.isEmpty { return "Carte •••• \(last)" }
        return "Carte bancaire"
    }

    private var canAdvance: Bool {
        switch step {
        case .number:  return numberIsValid
        case .details: return expiryIsValid
        case .design:  return true
        case .review:  return true
        }
    }

    /// Carte reconstruite en direct pour l'aperçu dynamique au sommet.
    private var previewCard: Card {
        var c = Card(kind: .bank, name: effectiveName)
        c.colorHex = colorHex
        c.holder = holder
        c.expiry = expiry
        if !numberDigits.isEmpty {
            c.lastFour = String(numberDigits.suffix(4))
            c.networkRaw = detectedNetwork.rawValue
            c.bankName = detectedBrandInfo.bankName ?? ""
            c.bankColorHex = detectedBrandInfo.brandColors?.first ?? ""
        }
        c.manualNetworkRaw = manualNetwork == .unknown ? "" : manualNetwork.rawValue
        c.designID = designID
        c.showChip = showChip
        c.hasCustomArt = customArtImage != nil
        return c
    }

    // MARK: - Corps

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. Barre de progression ultra-fine et discrète
                progressHeader
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                // 2. Contenu défilant fluide
                ScrollView(showsIndicators: false) {
                    VStack(spacing: focusedField != nil ? 14 : 20) {
                        // Carte Réaliste 3D avec adaptation douce au clavier
                        RealisticCardView(
                            card: previewCard,
                            revealedNumber: numberDigits.isEmpty ? nil : numberDigits,
                            artOverride: customArtImage,
                            enableTilt: true,
                            showChipOverride: showChip
                        )
                        .scaleEffect(focusedField != nil ? 0.85 : 1.0, anchor: .top)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .animation(Motion.snappy, value: focusedField != nil)
                        .animation(Motion.snappy, value: colorHex)
                        .animation(Motion.snappy, value: manualNetwork)
                        .animation(Motion.snappy, value: numberDigits)
                        .animation(Motion.snappy, value: designID)
                        .animation(Motion.snappy, value: customArtImage != nil)
                        .animation(Motion.snappy, value: showChip)

                        // En-tête typographique de l'étape
                        stepHeader

                        // Contenu de l'étape
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

                // 3. Pied de page avec bouton d'action principal
                footer
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(Color(uiColor: .systemBackground).opacity(0.90))
            }
            .navigationTitle("Nouvelle carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step != .number {
                        Button {
                            goBack()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Retour")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(Color.stashRed)
                        }
                    } else {
                        Button("Annuler") {
                            dismiss()
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                }
            }
            .onAppear {
                focusField(for: step)
            }
            .onChange(of: step) { _, newStep in
                focusField(for: newStep)
            }
        }
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
                    let brand = BINDatabase.brandInfo(for: number.filter(\.isNumber))
                    if let bank = brand.bankName, self.name.isEmpty {
                        self.name = bank
                    }
                }
            )
        }
    }

    // MARK: - Barre de progression délicate

    private var progressHeader: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 2.5)

                    Capsule()
                        .fill(Color.stashRed)
                        .frame(
                            width: max(0, geo.size.width * CGFloat(step.rawValue + 1) / CGFloat(Step.allCases.count)),
                            height: 2.5
                        )
                        .animation(Motion.snappy, value: step)
                }
            }
            .frame(height: 2.5)
            .padding(.horizontal, 24)

            HStack {
                Text("Étape \(step.rawValue + 1) sur \(Step.allCases.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer()

                Text(step.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.stashRed)
            }
            .padding(.horizontal, 26)
        }
    }

    // MARK: - En-tête d'étape

    private var stepHeader: some View {
        VStack(spacing: 3) {
            Text(step.title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)

            Text(step.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .id("header-\(step.rawValue)")
        .transition(.opacity)
    }

    // MARK: - Contenu par étape

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .number:  numberStep
        case .details: detailsStep
        case .design:  cardArtStudioStep
        case .review:  reviewStep
        }
    }

    // MARK: - Étape 1 : Numéro

    private var numberStep: some View {
        VStack(spacing: 16) {
            // Bloc de saisie
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "creditcard.fill")
                        .font(.title3)
                        .foregroundStyle(Color.stashRed)

                    TextField("•••• •••• •••• ••••", text: $fullNumber)
                        .keyboardType(.numberPad)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .textContentType(.creditCardNumber)
                        .focused($focusedField, equals: .number)
                        .onChange(of: fullNumber) { _, newValue in
                            fullNumber = formatCardNumber(newValue)
                            if name.isEmpty, let bank = detectedBrandInfo.bankName {
                                name = bank
                            }
                            if designID.isEmpty {
                                let recs = CardDesign.recommended(
                                    network: detectedNetwork,
                                    bankName: detectedBrandInfo.bankName ?? ""
                                )
                                if let firstRec = recs.first {
                                    designID = firstRec.id
                                }
                            }
                        }

                    if !numberDigits.isEmpty && detectedNetwork != .unknown {
                        Text(detectedNetwork.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.stashRed, in: Capsule())
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(16)
                .glassPanel(cornerRadius: 16)

                // Badge de banque détectée
                if let bank = detectedBrandInfo.bankName {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Émetteur : \(bank)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .transition(.opacity)
                }

                // Validation Luhn en temps réel
                if !numberDigits.isEmpty {
                    if numberIsValid {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text("Numéro valide (clé Luhn)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 6)
                        .transition(.opacity)
                    } else if numberDigits.count >= 13 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("Vérifie les chiffres de ta carte.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, 6)
                        .transition(.opacity)
                    }
                }
            }

            // Bouton de scan appareil photo unique et soigné
            Button {
                Haptics.light()
                showingScanner = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Scanner avec l'appareil photo")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .glassPanel(cornerRadius: 14)
                .foregroundStyle(Color.stashRed)
            }
            .buttonStyle(.plain)
        }
        .animation(Motion.snappy, value: detectedNetwork)
        .animation(Motion.snappy, value: numberIsValid)
    }

    // MARK: - Étape 2 : Détails

    private var detailsStep: some View {
        VStack(spacing: 16) {
            // Expiration & Titulaire
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expiration")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextField("MM/AA", text: $expiry)
                            .keyboardType(.numbersAndPunctuation)
                            .font(.body.weight(.semibold).monospaced())
                            .focused($focusedField, equals: .expiry)
                            .onChange(of: expiry) { _, newValue in
                                expiry = formatExpiry(newValue)
                            }
                    }

                    Divider().frame(height: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Titulaire sur la carte")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextField("Prénom Nom", text: $holder)
                            .textInputAutocapitalization(.words)
                            .textContentType(.name)
                            .font(.body.weight(.semibold))
                            .focused($focusedField, equals: .holder)
                    }
                }
                .padding(14)
                .glassPanel(cornerRadius: 16)

                if !expiryIsValid {
                    Text("Date d'expiration invalide ou déjà expirée.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }

            // Nom personnalisé
            VStack(alignment: .leading, spacing: 6) {
                Text("Nom dans Stash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(.secondary)
                    TextField("Ex. Bourso perso, Compte joint…", text: $name)
                        .font(.body)
                        .focused($focusedField, equals: .name)
                }
                .padding(14)
                .glassPanel(cornerRadius: 14)
            }

            // Réseau bancaire manuel (optionnel)
            VStack(alignment: .leading, spacing: 6) {
                Text("Réseau bancaire")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                Picker("Réseau", selection: $manualNetwork) {
                    Text("Auto (\(detectedNetwork == .unknown ? "Inconnu" : detectedNetwork.label))").tag(CardNetwork.unknown)
                    ForEach(CardNetwork.selectable) { net in
                        Text(net.label).tag(net)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .animation(Motion.snappy, value: expiryIsValid)
    }

    // MARK: - Étape 3 : CardArt Studio

    private var cardArtStudioStep: some View {
        CardArtStudioView(
            selectedDesignID: $designID,
            customArtImage: $customArtImage,
            colorHex: $colorHex,
            showChip: $showChip,
            recommendedNetwork: detectedNetwork,
            detectedBankName: detectedBrandInfo.bankName ?? ""
        )
    }

    // MARK: - Étape 4 : Scellé & Sécurité

    private var reviewStep: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                reviewRow("Nom", effectiveName)
                reviewRow("Réseau", effectiveNetwork == .unknown ? "Automatique" : effectiveNetwork.label)
                reviewRow("Numéro", "•••• •••• •••• \(String(numberDigits.suffix(4)))")
                reviewRow("Titulaire", holder.isEmpty ? "—" : holder)
                reviewRow("Expiration", expiry.isEmpty ? "—" : expiry)
                if let design = CardDesign.find(designID) {
                    reviewRow("Visuel choisi", design.name)
                } else if customArtImage != nil {
                    reviewRow("Visuel choisi", "Image personnalisée (CardArt)")
                }
            }
            .padding(16)
            .glassPanel(cornerRadius: 16)

            HStack(spacing: 12) {
                Image(systemName: "faceid")
                    .font(.title)
                    .foregroundStyle(Color.stashRed)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Coffre-fort chiffré Keychain")
                        .font(.subheadline.weight(.semibold))
                    Text("Le numéro complet est protégé par la puce matérielle Secure Enclave.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .glassPanel(cornerRadius: 14)
        }
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

    // MARK: - Pied de page

    private var footer: some View {
        Button {
            if step == .review {
                save()
            } else {
                goNext()
            }
        } label: {
            HStack(spacing: 8) {
                if step == .review {
                    Image(systemName: "lock.shield.fill")
                        .font(.body.weight(.bold))
                }
                Text(step == .review ? "Enregistrer dans mon coffre-fort" : "Continuer")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                canAdvance ? Color.stashRed : Color.secondary.opacity(0.18),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .foregroundStyle(canAdvance ? Color.white : Color.secondary)
            .shadow(color: canAdvance ? Color.stashRed.opacity(0.35) : Color.clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!canAdvance)
    }

    // MARK: - Navigation & Transitions

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isGoingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isGoingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

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

    private func focusField(for step: Step) {
        switch step {
        case .number:  focusedField = .number
        case .details: focusedField = expiry.isEmpty ? .expiry : .name
        case .design, .review: focusedField = nil
        }
    }

    // MARK: - Formatage

    private func formatCardNumber(_ input: String) -> String {
        var digits = input.filter(\.isNumber)
        let network = CardNetwork.detect(from: digits)
        let maxLength = network.validLengths.max() ?? 19
        if digits.count > maxLength {
            digits = String(digits.prefix(maxLength))
        }
        return groupNumber(digits, sizes: network.groupSizes)
    }

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
        card.showChip = showChip

        if let customArtImage {
            do {
                try ArtVault.save(customArtImage, for: card.id.uuidString)
                card.hasCustomArt = true
            } catch {
                print("Erreur d'enregistrement ArtVault : \(error)")
            }
        }

        do {
            try store.upsert(card, fullNumber: fullNumber)
            Haptics.success()
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
