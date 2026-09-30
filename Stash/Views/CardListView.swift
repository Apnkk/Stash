import SwiftUI

/// Écran principal : la liste de toutes les cartes.
struct CardListView: View {
    @EnvironmentObject private var store: CardStore

    @State private var showingForm = false
    @State private var editingCard: Card?
    @State private var searchText = ""
    @State private var showingSettings = false

    private var filteredCards: [Card] {
        guard !searchText.isEmpty else { return store.cards }
        let query = searchText.lowercased()
        return store.cards.filter {
            $0.name.lowercased().contains(query) || $0.code.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.cards.isEmpty {
                    emptyState
                } else {
                    cardGrid
                }
            }
            .navigationTitle("Stash")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .glassButtonIfAvailable()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingCard = nil
                        showingForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .glassButtonIfAvailable()
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher une carte")
            .sheet(isPresented: $showingForm) {
                CardFormView(card: editingCard)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(store)
            }
        }
    }

    private var cardGrid: some View {
        List {
            ForEach(filteredCards) { card in
                ZStack {
                    NavigationLink {
                        CardDetailView(card: card)
                            .environmentObject(store)
                    } label: {
                        EmptyView()
                    }
                    .opacity(0)

                    CardTileView(card: card)
                }
                .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onMove(perform: searchText.isEmpty ? move : nil)
            .onDelete(perform: searchText.isEmpty ? deleteCards : nil)
        }
        .listStyle(.plain)
    }

    /// Réordonne dans le store (uniquement hors recherche).
    private func move(from source: IndexSet, to destination: Int) {
        store.move(from: source, to: destination)
    }

    /// Supprime les cartes correspondant aux positions de la liste filtrée.
    private func deleteCards(at offsets: IndexSet) {
        let ids = offsets.map { filteredCards[$0].id }
        let storeOffsets = IndexSet(store.cards.enumerated().compactMap { ids.contains($0.element.id) ? $0.offset : nil })
        store.delete(at: storeOffsets)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Aucune carte")
                .font(.title2.weight(.bold))
            Text("Ajoute ta première carte de fidélité ou bancaire. Tout reste chiffré sur ton téléphone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                editingCard = nil
                showingForm = true
            } label: {
                Label("Ajouter une carte", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .glassProminentButtonIfAvailable()
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Vignette d'une carte dans la grille.
struct CardTileView: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if card.kind == .bank {
                    // Puce EMV miniature, pour évoquer la carte physique.
                    miniChip
                } else {
                    Image(systemName: "barcode")
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Text(card.kind.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.18), in: Capsule())
            }

            Spacer()

            Text(card.name)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(subtitle)
                .font(.subheadline.monospaced())
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
        .padding(18)
        .frame(height: 130)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: card.colorHex), Color(hex: card.colorHex).opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            if #available(iOS 26, *) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
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
        case .bank:
            return "•••• •••• •••• \(card.lastFour.isEmpty ? "••••" : card.lastFour)"
        }
    }
}
