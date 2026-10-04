import SwiftUI

enum StashDisplayMode: String, CaseIterable, Identifiable {
    case walletStack = "stack"
    case grid = "grid"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .walletStack: return "Pile Wallet"
        case .grid: return "Grille"
        }
    }
}

/// Écran principal : la liste de toutes les cartes.
struct CardListView: View {
    @EnvironmentObject private var store: CardStore

    @State private var showingForm = false
    @State private var showingTypePicker = false
    @State private var editingCard: Card?
    @State private var searchText = ""
    @State private var showingSettings = false
    @State private var selectedCardForDetail: Card?
    /// Carte mise en avant à l'accueil juste après son ajout.
    @State private var highlightedID: UUID?

    @AppStorage("stash_display_mode") private var displayModeRaw = StashDisplayMode.walletStack.rawValue
    @AppStorage("card_sort_option") private var sortOptionRaw = CardSortOption.manual.rawValue
    @AppStorage("pin_favorites") private var pinFavorites = true
    @State private var filterOption: CardFilterOption = .all

    private var filteredCards: [Card] {
        let sortOption = CardSortOption(rawValue: sortOptionRaw) ?? .manual
        return store.cards
            .filtered(by: filterOption, query: searchText)
            .sorted(by: sortOption, pinFavorites: pinFavorites)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !store.cards.isEmpty {
                    filterBar
                }

                Group {
                    if store.cards.isEmpty {
                        emptyState
                    } else if filteredCards.isEmpty {
                        noResultsState
                    } else if displayModeRaw == StashDisplayMode.walletStack.rawValue {
                        WalletStackView(
                            cards: filteredCards,
                            onOpenDetail: { card in
                                selectedCardForDetail = card
                            },
                            onEditCard: { card in
                                editingCard = card
                                showingForm = true
                            }
                        )
                    } else {
                        cardGrid
                    }
                }
            }
            .navigationTitle("Stash")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.light()
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .glassButtonIfAvailable()
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Haptics.selection()
                        withAnimation(Motion.snappy) {
                            displayModeRaw = (displayModeRaw == StashDisplayMode.walletStack.rawValue)
                                ? StashDisplayMode.grid.rawValue
                                : StashDisplayMode.walletStack.rawValue
                        }
                    } label: {
                        Image(systemName: displayModeRaw == StashDisplayMode.walletStack.rawValue ? "square.grid.2x2" : "square.stack.3d.up.fill")
                    }
                    .accessibilityLabel(displayModeRaw == StashDisplayMode.walletStack.rawValue ? "Afficher en grille" : "Afficher en pile Wallet")
                    .glassButtonIfAvailable()

                    Menu {
                        Section("Trier par") {
                            Picker("Tri", selection: $sortOptionRaw) {
                                ForEach(CardSortOption.allCases) { option in
                                    Label(option.label, systemImage: option.icon).tag(option.rawValue)
                                }
                            }
                        }
                        Section {
                            Toggle(isOn: $pinFavorites) {
                                Label("Épingler les favoris", systemImage: "star.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .glassButtonIfAvailable()

                    Button {
                        Haptics.medium()
                        showingTypePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .glassButtonIfAvailable()
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher une carte")
            .navigationDestination(item: $selectedCardForDetail) { card in
                CardDetailView(card: card)
            }
            .onReceive(NotificationCenter.default.publisher(for: .stashOpenCard)) { notif in
                if let id = notif.userInfo?["cardID"] as? UUID,
                   let card = store.cards.first(where: { $0.id == id }) {
                    selectedCardForDetail = card
                }
            }
            .onAppear {
                SpotlightService.updateIndex(with: store.cards)
            }
            .onChange(of: store.cards) { _, newCards in
                SpotlightService.updateIndex(with: newCards)
            }
            .sheet(isPresented: $showingForm) {
                CardFormView(card: editingCard)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingTypePicker, onDismiss: highlightNewCard) {
                AddCardTypeView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(store)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CardFilterOption.allCases) { filter in
                    Button {
                        Haptics.selection()
                        withAnimation(Motion.snappy) {
                            filterOption = filter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.caption2)
                            Text(filter.label)
                                .font(.caption.weight(filterOption == filter ? .semibold : .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            filterOption == filter ? Color.stashRed : Color.secondary.opacity(0.15),
                            in: Capsule()
                        )
                        .foregroundStyle(filterOption == filter ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Aucune carte trouvée")
                .font(.headline)
            Text("Essaie de modifier ta recherche ou le filtre actif.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var canReorder: Bool {
        searchText.isEmpty && filterOption == .all && sortOptionRaw == CardSortOption.manual.rawValue
    }

    private var cardGrid: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(filteredCards.enumerated()), id: \.element.id) { index, card in
                    ZStack {
                        NavigationLink {
                            CardDetailView(card: card)
                                .environmentObject(store)
                        } label: {
                            EmptyView()
                        }
                        .opacity(0)

                        CardTileView(card: card, isHighlighted: card.id == highlightedID)
                            .pressable()
                    }
                    .id(card.id)
                    .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .appearInCascade(index: index)
                    .transition(.cardAppear)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            Haptics.light()
                            withAnimation(Motion.snappy) {
                                store.toggleFavorite(card)
                            }
                        } label: {
                            Label(
                                card.isFavorite ? "Défavoriser" : "Favori",
                                systemImage: card.isFavorite ? "star.slash.fill" : "star.fill"
                            )
                        }
                        .tint(.yellow)
                    }
                }
                .onMove(perform: canReorder ? move : nil)
                .onDelete(perform: deleteCards)
            }
            .listStyle(.plain)
            .animation(Motion.standard, value: filteredCards.map(\.id))
            .onChange(of: highlightedID) { _, id in
                // Fait défiler jusqu'à la nouvelle carte (ajoutée en fin de liste).
                guard let id else { return }
                withAnimation(Motion.soft) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    /// Appelé à la fermeture de la feuille d'ajout : si une carte vient d'être
    /// créée, on la met en avant quelques secondes puis on retire l'effet.
    private func highlightNewCard() {
        guard let id = store.lastAddedCardID else { return }
        store.clearLastAdded()
        searchText = ""
        highlightedID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(Motion.soft) {
                if highlightedID == id { highlightedID = nil }
            }
        }
    }

    /// Réordonne dans le store (uniquement hors recherche).
    private func move(from source: IndexSet, to destination: Int) {
        Haptics.selection()
        withAnimation(Motion.standard) {
            store.move(from: source, to: destination)
        }
    }

    /// Supprime les cartes correspondant aux positions de la liste filtrée.
    private func deleteCards(at offsets: IndexSet) {
        let toDelete = offsets.map { filteredCards[$0] }
        Haptics.rigid()
        withAnimation(Motion.standard) {
            for card in toDelete {
                store.delete(card)
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView {
            showingTypePicker = true
        }
    }
}

/// État vide animé : l'icône respire doucement pour donner vie à l'écran,
/// et l'ensemble apparaît en fondu montant.
private struct EmptyStateView: View {
    var onAdd: () -> Void

    @State private var pulse = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .scaleEffect(pulse ? 1.06 : 0.94)
                .animation(
                    .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                    value: pulse
                )
            Text("Aucune carte")
                .font(.title2.weight(.bold))
            Text("Ajoute ta première carte de fidélité ou bancaire. Tout reste chiffré sur ton téléphone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                onAdd()
            } label: {
                Label("Ajouter une carte", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .glassProminentButtonIfAvailable()
            .pressable()
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            pulse = true
            withAnimation(Motion.soft) { appeared = true }
        }
    }
}

/// Vignette d'une carte dans la grille.
struct CardTileView: View {
    let card: Card
    /// `true` juste après l'ajout de cette carte : déclenche un halo + zoom.
    var isHighlighted: Bool = false

    @State private var glow = false

    /// Image de fond éventuelle de la vignette (chargée depuis ArtVault).
    private var backgroundArt: UIImage? {
        guard card.hasCustomArt else { return nil }
        return ArtVault.load(card.id.uuidString)
    }

    /// Couleurs de fond de la vignette : dégradé de marque de la banque
    /// détectée si l'utilisateur a gardé la couleur par défaut, sinon sa
    /// couleur personnalisée.
    private var tileColors: [Color] {
        let usesDefaultColor = card.colorHex.uppercased() == "#D62836"
        if card.kind == .bank, usesDefaultColor {
            // Un design de réseau choisi à la main prime sur la banque détectée.
            let manual = CardNetwork(rawValue: card.manualNetworkRaw)
            if let manual, manual != .unknown {
                return manual.brandColors.map { Color(hex: $0) }
            }
            if !card.bankColorHex.isEmpty {
                let base = Color(hex: card.bankColorHex)
                return [base, base.opacity(0.78)]
            }
        }
        let base = Color(hex: card.colorHex)
        return [base, base.opacity(0.75)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if card.kind == .bank {
                    // Puce EMV miniature, pour évoquer la carte physique.
                    miniChip
                } else {
                    Image(systemName: card.kind == .other ? "rectangle.stack.fill" : "barcode")
                        .foregroundStyle(.white.opacity(0.9))
                }

                if card.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.35), in: Capsule())
                }

                Spacer()
                // Logo réseau (Visa/Mastercard/…) figé à la saisie, sinon le
                // libellé du type de carte.
                if card.kind == .bank, card.network != .unknown {
                    tileNetworkLogo
                } else {
                    Text(card.kind.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.18), in: Capsule())
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if card.kind == .bank, !card.bankName.isEmpty {
                    Text(card.bankName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Text(subtitle)
                .font(.subheadline.monospaced())
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
        .padding(18)
        .frame(height: 130)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if let design = CardDesign.find(card.designID) {
                design.image
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.12), .black.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else if let backgroundArt {
                Image(uiImage: backgroundArt)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        // Voile sombre pour garder le texte lisible sur l'image.
                        LinearGradient(
                            colors: [.black.opacity(0.15), .black.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                LinearGradient(
                    colors: tileColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .overlay {
            if #available(iOS 26, *) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            // Liseré lumineux qui pulse brièvement pour la carte tout juste ajoutée.
            if isHighlighted {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(glow ? 0.9 : 0.4), lineWidth: glow ? 3 : 1.5)
                    .shadow(color: Color.stashRed.opacity(glow ? 0.7 : 0.3), radius: glow ? 16 : 6)
                    .allowsHitTesting(false)
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        .scaleEffect(isHighlighted && glow ? 1.03 : 1)
        .animation(.easeInOut(duration: 0.8).repeatCount(3, autoreverses: true), value: glow)
        .onChange(of: isHighlighted) { _, newValue in
            if newValue {
                Haptics.success()
                glow = true
            } else {
                glow = false
            }
        }
        .onAppear {
            // Cas où la tuile apparaît déjà surlignée (retour direct sur l'accueil).
            if isHighlighted { glow = true }
        }
    }

    /// Logo réseau miniature affiché en haut à droite de la vignette bancaire,
    /// cohérent avec celui de RealisticCardView.
    @ViewBuilder
    private var tileNetworkLogo: some View {
        switch card.network {
        case .mastercard:
            HStack(spacing: -7) {
                Circle().fill(Color(hex: "#EB001B")).frame(width: 18, height: 18)
                Circle().fill(Color(hex: "#F79E1B").opacity(0.9)).frame(width: 18, height: 18)
            }
        case .visa, .amex, .discover:
            Text(card.network == .amex ? "AMEX" : card.network.label)
                .font(.caption2.weight(.heavy))
                .italic(card.network == .visa)
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.white.opacity(0.18), in: Capsule())
        case .unknown:
            EmptyView()
        }
    }

    /// Puce EMV miniature dorée, cohérente avec RealisticCardView.
    private var miniChip: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#E7C766"), Color(hex: "#B8912F")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 22)
            Rectangle()
                .fill(.black.opacity(0.28))
                .frame(width: 1, height: 14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(.black.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var subtitle: String {
        switch card.kind {
        case .loyalty:
            return card.code
        case .other:
            return card.code.isEmpty ? "Carte" : card.code
        case .bank:
            return "•••• •••• •••• \(card.lastFour.isEmpty ? "••••" : card.lastFour)"
        }
    }
}
