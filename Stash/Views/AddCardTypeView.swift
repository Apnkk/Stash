import SwiftUI

/// Écran de sélection du type de carte, présenté avant le formulaire d'ajout.
///
/// Style iOS/Apple : grande accroche, deux grandes tuiles « premium » en verre
/// qui décrivent chaque type, apparition en cascade et retour au toucher.
/// Une fois le type choisi, on enchaîne sur `CardFormView` avec ce type
/// pré-sélectionné (et verrouillé, comme en édition).
struct AddCardTypeView: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss

    /// Type choisi par l'utilisateur ; déclenche la navigation vers le formulaire.
    @State private var selectedKind: CardKind?
    @State private var headerVisible = false

    var body: some View {
        NavigationStack {
            ZStack {
                backdrop

                VStack(spacing: 0) {
                    header
                        .padding(.top, 8)
                        .padding(.horizontal, 24)

                    VStack(spacing: 16) {
                        ForEach(Array(CardKind.allCases.enumerated()), id: \.element.id) { index, kind in
                            CardTypeOption(kind: kind) {
                                choose(kind)
                            }
                            .appearInCascade(index: index + 1)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                    Spacer(minLength: 0)
                }
                .padding(.top, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            // Navigation vers le formulaire une fois le type choisi.
            .navigationDestination(item: $selectedKind) { kind in
                CardFormView(card: nil, presetKind: kind)
                    .environmentObject(store)
            }
        }
    }

    /// En-tête : titre d'accroche + sous-titre, avec apparition douce.
    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.stashRed, Color.stashRed.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.stashRed.opacity(0.4), radius: 12, y: 6)
                Image(systemName: "wallet.bifold.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Ajouter une carte")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            Text("Choisis le type de carte à ajouter à ton portefeuille.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : 18)
        .onAppear {
            withAnimation(Motion.soft) { headerVisible = true }
        }
    }

    /// Léger dégradé de fond pour donner de la profondeur, discret.
    private var backdrop: some View {
        LinearGradient(
            colors: [
                Color.stashRed.opacity(0.10),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }

    private func choose(_ kind: CardKind) {
        Haptics.medium()
        withAnimation(Motion.standard) {
            selectedKind = kind
        }
    }
}

/// Une grande tuile de choix : icône, titre, description, chevron.
/// Fond en verre (Liquid Glass sur iOS 26, matériau en dessous), enfoncement
/// au toucher via `pressable`, et accent coloré propre à chaque type.
private struct CardTypeOption: View {
    let kind: CardKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                iconBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(cornerRadius: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .pressable()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }

    /// Pastille d'icône colorée selon le type.
    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
                .shadow(color: accentColor.opacity(0.35), radius: 6, y: 3)
            Image(systemName: iconName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var iconName: String {
        switch kind {
        case .bank:    return "creditcard.fill"
        case .loyalty: return "barcode"
        }
    }

    private var title: String {
        switch kind {
        case .bank:    return "Carte bancaire"
        case .loyalty: return "Carte de fidélité"
        }
    }

    private var subtitle: String {
        switch kind {
        case .bank:    return "Numéro chiffré dans le trousseau, consultation protégée par Face ID."
        case .loyalty: return "Code-barres ou QR code, à scanner en caisse."
        }
    }

    private var accentColor: Color {
        switch kind {
        case .bank:    return Color(hex: "#2A4BD7")
        case .loyalty: return Color.stashRed
        }
    }
}
