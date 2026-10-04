import SwiftUI

/// Vue en pile de cartes superposées façon Apple Wallet.
///
/// Permet de feuilleter toutes ses cartes dans une pile compacte :
/// - Superposition fluide avec décalage vertical naturel
/// - Sélection interactive avec animation de ressort (spring physics)
/// - Déploiement instantané du code-barres ou de la carte bancaire
/// - Prise en charge du geste de glissement pour replier la carte
struct WalletStackView: View {
    @EnvironmentObject private var store: CardStore

    let cards: [Card]
    let onOpenDetail: (Card) -> Void
    let onEditCard: (Card) -> Void

    @State private var expandedCardID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var showingPresentationCard: Card?
    @State private var barcodeCache: [UUID: UIImage] = [:]

    private let collapsedCardOffset: CGFloat = 68
    private let cardHeight: CGFloat = 210

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .top) {
                    // Espace réservé pour permettre le défilement complet
                    Color.clear
                        .frame(height: totalStackHeight)

                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        let isExpanded = expandedCardID == card.id
                        let isAnyExpanded = expandedCardID != nil

                        WalletStackItemView(
                            card: card,
                            isExpanded: isExpanded,
                            isAnyExpanded: isAnyExpanded,
                            cachedBarcode: barcodeCache[card.id],
                            onTap: {
                                handleCardTap(card, at: index, proxy: proxy)
                            },
                            onOpenDetail: {
                                onOpenDetail(card)
                            },
                            onPresentCheckout: {
                                showingPresentationCard = card
                            }
                        )
                        .offset(y: calculateOffset(for: index, isExpanded: isExpanded))
                        .offset(y: isExpanded ? max(0, dragOffset) : 0)
                        .zIndex(isExpanded ? 999 : Double(index))
                        .animation(Motion.spring, value: expandedCardID)
                        .animation(Motion.spring, value: dragOffset)
                        .gesture(
                            isExpanded ? DragGesture()
                                .onChanged { value in
                                    if value.translation.height > 0 {
                                        dragOffset = value.translation.height
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height > 80 || value.velocity.height > 300 {
                                        collapseStack()
                                    } else {
                                        withAnimation(Motion.spring) {
                                            dragOffset = 0
                                        }
                                    }
                                } : nil
                        )
                        .id(card.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 80)
            }
        }
        .fullScreenCover(item: $showingPresentationCard) { card in
            PresentationModeView(
                card: card,
                barcodeImage: barcodeCache[card.id] ?? BarcodeGenerator.generate(for: card)
            )
        }
        .task(id: cards.map(\.id)) {
            preloadBarcodes()
        }
    }

    // MARK: - Calculs géométriques

    private var totalStackHeight: CGFloat {
        if expandedCardID != nil {
            return cardHeight + 420
        }
        return CGFloat(max(0, cards.count - 1)) * collapsedCardOffset + cardHeight + 40
    }

    private func calculateOffset(for index: Int, isExpanded: Bool) -> CGFloat {
        guard let expandedID = expandedCardID,
              let expandedIndex = cards.firstIndex(where: { $0.id == expandedID }) else {
            // Mode empilé normal
            return CGFloat(index) * collapsedCardOffset
        }

        if isExpanded {
            // La carte active remonte au premier plan
            return 8
        } else if index < expandedIndex {
            // Les cartes au-dessus se décalent légèrement vers le haut
            return CGFloat(index) * 20
        } else {
            // Les cartes en dessous glissent vers le bas
            return cardHeight + 200 + CGFloat(index - expandedIndex) * 30
        }
    }

    // MARK: - Interactions

    private func handleCardTap(_ card: Card, at index: Int, proxy: ScrollViewProxy) {
        Haptics.selection()
        if expandedCardID == card.id {
            collapseStack()
        } else {
            withAnimation(Motion.spring) {
                expandedCardID = card.id
                dragOffset = 0
            }
            withAnimation(Motion.spring.delay(0.05)) {
                proxy.scrollTo(card.id, anchor: .top)
            }
        }
    }

    private func collapseStack() {
        Haptics.light()
        withAnimation(Motion.spring) {
            expandedCardID = nil
            dragOffset = 0
        }
    }

    private func preloadBarcodes() {
        for card in cards where card.kind != .bank && barcodeCache[card.id] == nil {
            if let image = BarcodeGenerator.generate(for: card) {
                barcodeCache[card.id] = image
            }
        }
    }
}

// MARK: - Élément individuel de la pile

private struct WalletStackItemView: View {
    let card: Card
    let isExpanded: Bool
    let isAnyExpanded: Bool
    let cachedBarcode: UIImage?
    let onTap: () -> Void
    let onOpenDetail: () -> Void
    let onPresentCheckout: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Carte principale
            Button(action: onTap) {
                if card.kind == .bank {
                    RealisticCardView(card: card, showsDetails: isExpanded)
                } else {
                    loyaltyPassView
                }
            }
            .buttonStyle(WalletCardButtonStyle())
            .shadow(
                color: Color.black.opacity(isExpanded ? 0.4 : 0.22),
                radius: isExpanded ? 24 : 10,
                x: 0,
                y: isExpanded ? 12 : 5
            )

            // Panneau d'actions qui apparaît quand la carte est dépliée
            if isExpanded {
                expandedActionsPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .opacity(isAnyExpanded && !isExpanded ? 0.45 : 1.0)
        .scaleEffect(isAnyExpanded && !isExpanded ? 0.96 : 1.0)
    }

    // MARK: Passe Fidélité
    private var loyaltyPassView: some View {
        ZStack(alignment: .topLeading) {
            // Fond dégradé
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: card.colorHex),
                            Color(hex: card.colorHex).opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 12) {
                // Header du pass
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text("CARTE DE FIDÉLITÉ")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white.opacity(0.75))
                            .tracking(1.2)
                    }

                    Spacer()

                    if card.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.subheadline)
                            .foregroundStyle(.yellow)
                            .padding(6)
                            .background(.black.opacity(0.25), in: Circle())
                    }
                }

                Spacer()

                // Si déplié dans le pass, petit aperçu du code
                HStack {
                    Image(systemName: card.format == .qr ? "qrcode" : "barcode")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(card.code)
                        .font(.callout.weight(.semibold).monospaced())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(18)
        }
        .frame(height: 200)
    }

    // MARK: Panneau déplié
    private var expandedActionsPanel: some View {
        VStack(spacing: 14) {
            if card.kind != .bank {
                // Aperçu du code-barres / QR
                if let image = cachedBarcode {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white)
                            .frame(height: 140)

                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .padding(14)
                    }
                }

                // Boutons d'action rapides
                HStack(spacing: 10) {
                    Button(action: onPresentCheckout) {
                        Label("Plein écran caisse", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.stashRed)

                    Button(action: onOpenDetail) {
                        Label("Détails", systemImage: "info.circle")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Actions carte bancaire
                Button(action: onOpenDetail) {
                    Label("Afficher les numéros secrets", systemImage: "faceid")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.stashRed)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }
}

/// Style de bouton neutre sans atténuation automatique pour préserver le rendu
private struct WalletCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}
