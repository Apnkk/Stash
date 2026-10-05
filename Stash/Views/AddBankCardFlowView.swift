import SwiftUI
import PhotosUI

/// Flux d'ajout d'une carte bancaire inspiré d'Apple Wallet :
/// immersif, élégant, avec prévisualisation réaliste en temps réel et
/// galerie interactive de designs CardArt intégrée directement dans le flux.
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
            case .details: return "Détails de la carte"
            case .design:  return "Design CardArt"
            case .review:  return "Vérification"
            }
        }

        var subtitle: String {
            switch self {
            case .number:  return "Saisis ou scanne les chiffres de ta carte bancaire."
            case .details: return "Date d'expiration, titulaire et nom personnalisé."
            case .design:  return "Sélectionne un visuel officiel CardArt ou importe une image."
            case .review:  return "Vérifie les informations avant l'enregistrement sécurisé."
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
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    @State private var selectedDesignCategory: CardDesignCategory = .all
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

    /// Carte reconstruite en direct pour l'aperçu instantané en haut de l'écran.
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
        c.hasCustomArt = customArtImage != nil
        return c
    }

    /// Designs à afficher selon la catégorie sélectionnée ou la recommandation automatique.
    private var filteredDesigns: [CardDesign] {
        if selectedDesignCategory == .all {
            return CardDesign.allDesigns
        }
        return CardDesign.allDesigns.filter { $0.category == selectedDesignCategory }
    }

    // MARK: - Corps

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. Barre de progression discrète
                steppedProgressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                // 2. Contenu défilant avec la carte en vedette
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Carte Réaliste toujours visible en haut (avec morphing dynamique)
                        RealisticCardView(
                            card: previewCard,
                            revealedNumber: numberDigits.isEmpty ? nil : numberDigits,
                            artOverride: customArtImage
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .animation(Motion.snappy, value: colorHex)
                        .animation(Motion.snappy, value: manualNetwork)
                        .animation(Motion.snappy, value: numberDigits)
                        .animation(Motion.snappy, value: designID)
                        .animation(Motion.snappy, value: customArtImage != nil)

                        // En-tête de l'étape
                        stepHeader

                        // Contenu spécifique à l'étape
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

                // 3. Pied de page avec boutons de navigation
                footer
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(Color(uiColor: .systemBackground).opacity(0.85))
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
                                    .font(.subheadline.weight(.semibold))
                                Text("Retour")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(Color.stashRed)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary.opacity(0.8))
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
                    // Auto-détection intelligente du nom de la banque
                    let brand = BINDatabase.brandInfo(for: number.filter(\.isNumber))
                    if let bank = brand.bankName, self.name.isEmpty {
                        self.name = bank
                    }
                }
            )
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImg = UIImage(data: data) {
                    await MainActor.run {
                        self.customArtImage = uiImg
                        self.designID = ""
                        Haptics.selection()
                    }
                }
            }
        }
    }

    // MARK: - Barre de progression

    private var steppedProgressBar: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.stashRed : Color.secondary.opacity(0.18))
                    .frame(height: 3.5)
                    .animation(Motion.snappy, value: step)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Étape \(step.rawValue + 1) sur \(Step.allCases.count) : \(step.title)")
    }

    // MARK: - En-tête d'étape

    private var stepHeader: some View {
        VStack(spacing: 4) {
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
        case .design:  cardArtDesignStep
        case .review:  reviewStep
        }
    }

    // MARK: - Étape 1 : Numéro

    private var numberStep: some View {
        VStack(spacing: 16) {
            // Boîte de saisie principale
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "creditcard.fill")
                        .font(.title3)
                        .foregroundStyle(Color.stashRed)

                    TextField("1234 5678 9012 3456", text: $fullNumber)
                        .keyboardType(.numberPad)
                        .font(.title3.weight(.semibold).monospaced())
                        .textContentType(.creditCardNumber)
                        .focused($focusedField, equals: .number)
                        .onChange(of: fullNumber) { _, newValue in
                            fullNumber = formatCardNumber(newValue)
                            // Pré-remplit le nom si une banque est identifiée
                            if name.isEmpty, let bank = detectedBrandInfo.bankName {
                                name = bank
                            }
                            // Auto-sélectionne le design recommandé si disponible
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
                            .transition(.popIn)
                    }
                }
                .padding(16)
                .glassPanel(cornerRadius: 16)

                if let bank = detectedBrandInfo.bankName {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Banque détectée : \(bank)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                    .transition(.opacity)
                }

                if !numberDigits.isEmpty && !numberIsValid {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text("Vérifie les chiffres de ta carte (algorithme de Luhn).")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 4)
                    .transition(.opacity)
                }
            }

            // Bouton Scanner caméra unique et soigné
            Button {
                Haptics.light()
                showingScanner = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.body.weight(.semibold))
                    Text("Scanner avec la caméra")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.stashRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
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
            // Date d'expiration & Titulaire
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
                    Text("Date d'expiration invalide ou déjà dépassée.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }

            // Nom personnalisé de la carte
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

            // Choix manuel du réseau bancaire
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

    // MARK: - Étape 3 : Le Grand Choix du Design CardArt

    private var cardArtDesignStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Filtres thématiques CardArt
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CardDesignCategory.allCases) { cat in
                        Button {
                            Haptics.selection()
                            withAnimation(Motion.snappy) {
                                selectedDesignCategory = cat
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: cat.icon)
                                    .font(.caption2)
                                Text(cat.label)
                                    .font(.caption.weight(selectedDesignCategory == cat ? .semibold : .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                selectedDesignCategory == cat ? Color.stashRed : Color.secondary.opacity(0.14),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedDesignCategory == cat ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            // Grille visuelle des designs officiels CardArt
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                ForEach(filteredDesigns) { design in
                    cardArtDesignTile(design)
                }
            }

            Divider().padding(.vertical, 4)

            // Option 1 : Importer une carte personnalisée depuis Photos ou Fichiers
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Importer une image perso")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Choisis n'importe quelle carte parmi tes photos ou fichiers.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if customArtImage != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .glassPanel(cornerRadius: 14)
            }
            .buttonStyle(.plain)

            // Option 2 : Teinte & Couleur personnalisée
            VStack(alignment: .leading, spacing: 8) {
                Text("Ou choisis une couleur de carte :")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                colorPicker
            }
        }
    }

    private func cardArtDesignTile(_ design: CardDesign) -> some View {
        let isSelected = designID == design.id && customArtImage == nil

        return Button {
            Haptics.selection()
            withAnimation(Motion.snappy) {
                designID = design.id
                customArtImage = nil
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    design.image
                        .resizable()
                        .aspectRatio(1.585, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    isSelected ? Color.stashRed : Color.white.opacity(0.15),
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                        }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.white, Color.stashRed)
                            .padding(6)
                            .transition(.scale)
                    }
                }

                Text(design.name)
                    .font(.caption2.weight(isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.stashRed : Color.primary)
                    .lineLimit(1)
            }
            .padding(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Étape 4 : Récapitulatif

    private var reviewStep: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                reviewRow("Nom", effectiveName)
                reviewRow("Réseau", effectiveNetwork == .unknown ? "Automatique" : effectiveNetwork.label)
                reviewRow("Numéro", "•••• •••• •••• \(String(numberDigits.suffix(4)))")
                reviewRow("Titulaire", holder.isEmpty ? "—" : holder)
                reviewRow("Expiration", expiry.isEmpty ? "—" : expiry)
                if let design = CardDesign.find(designID) {
                    reviewRow("Design choisi", design.name)
                } else if customArtImage != nil {
                    reviewRow("Design choisi", "Image personnalisée")
                }
            }
            .padding(16)
            .glassPanel(cornerRadius: 16)

            HStack(spacing: 10) {
                Image(systemName: "faceid")
                    .font(.title2)
                    .foregroundStyle(Color.stashRed)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stockage sécurisé Keychain")
                        .font(.subheadline.weight(.semibold))
                    Text("Numéro complet chiffré. Accessible par Face ID ou code.")
                        .font(.caption)
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

    // MARK: - Nuancier de couleurs

    private var colorPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 10)], spacing: 10) {
            ForEach(Palette.colors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 34, height: 34)
                    .overlay {
                        if hex == colorHex && designID.isEmpty && customArtImage == nil {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                    }
                    .scaleEffect(hex == colorHex ? 1.08 : 1)
                    .onTapGesture {
                        Haptics.selection()
                        withAnimation(Motion.snappy) {
                            colorHex = hex
                            designID = ""
                            customArtImage = nil
                        }
                    }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Pied de page

    private var footer: some View {
        HStack(spacing: 12) {
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
                    }
                    Text(step == .review ? "Enregistrer la carte" : "Continuer")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canAdvance ? Color.stashRed : Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(canAdvance ? Color.white : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
        }
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

        // Si une image personnalisée a été importée depuis les photos
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
