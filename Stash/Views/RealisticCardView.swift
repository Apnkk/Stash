import SwiftUI

/// Rendu d'une carte bancaire physique réaliste : dégradé, puce EMV,
/// logo du réseau, numéro formaté par blocs, titulaire et expiration.
///
/// Le numéro complet n'est affiché que si `revealedNumber` est fourni
/// (après authentification côté vue de détail) ; sinon on masque tout
/// sauf les quatre derniers chiffres.
struct RealisticCardView: View {
    let card: Card
    /// Numéro complet déjà déchiffré, ou `nil` pour l'affichage masqué.
    var revealedNumber: String? = nil

    /// Réseau à utiliser pour l'apparence : d'abord celui figé à la saisie
    /// (persisté, non sensible), sinon détecté depuis le numéro révélé s'il
    /// est fourni. Permet d'afficher le bon logo même à l'accueil.
    private var network: CardNetwork {
        if card.network != .unknown {
            return card.network
        }
        if let number = revealedNumber {
            return CardNetwork.detect(from: number)
        }
        return .unknown
    }

    /// L'utilisateur a-t-il gardé la couleur par défaut ? Si oui, on habille
    /// la carte avec le dégradé de marque de la banque (prioritaire) ou du
    /// réseau détecté.
    private var usesDefaultColor: Bool {
        card.colorHex.uppercased() == "#D62836"
    }

    /// L'utilisateur a-t-il choisi un design de réseau manuellement ? Dans ce
    /// cas ses couleurs de marque priment sur celles de la banque détectée.
    private var hasManualNetwork: Bool {
        CardNetwork(rawValue: card.manualNetworkRaw).map { $0 != .unknown } ?? false
    }

    private var gradientColors: [Color] {
        if usesDefaultColor {
            // Un design de réseau choisi à la main prime sur la banque détectée.
            if hasManualNetwork, network != .unknown {
                return network.brandColors.map { Color(hex: $0) }
            }
            // Sinon, priorité aux couleurs de la banque détectée (persistées),
            // puis au dégradé du réseau.
            if !card.bankColorHex.isEmpty {
                let base = Color(hex: card.bankColorHex)
                return [base, base.opacity(0.78)]
            }
            if network != .unknown {
                return network.brandColors.map { Color(hex: $0) }
            }
        }
        let base = Color(hex: card.colorHex)
        return [base, base.opacity(0.72)]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    // Reflet diagonal discret pour un rendu « plastique ».
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.22), .clear],
                                startPoint: .topTrailing,
                                endPoint: .center
                            )
                        )
                        .allowsHitTesting(false)
                }

            VStack(alignment: .leading, spacing: 0) {
                // Ligne du haut : nom donné par l'utilisateur + logo réseau.
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                        if !card.bankName.isEmpty {
                            Text(card.bankName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    networkLogo
                }

                Spacer(minLength: 8)

                chip
                    .padding(.top, 6)

                Spacer(minLength: 8)

                Text(displayedNumber)
                    .font(.title3.weight(.semibold).monospaced())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)

                Spacer(minLength: 10)

                HStack(alignment: .bottom, spacing: 20) {
                    labelValue("TITULAIRE", card.holder.isEmpty ? "—" : card.holder.uppercased())
                    labelValue("EXPIRE", card.expiry.isEmpty ? "MM/AA" : card.expiry)
                    Spacer()
                }
            }
            .padding(20)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
    }

    // MARK: - Éléments

    /// Puce EMV stylisée (dorée, avec ses contacts).
    private var chip: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#E7C766"), Color(hex: "#B8912F")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 34)

            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(.black.opacity(0.28))
                        .frame(height: 1)
                }
            }
            .frame(width: 34)

            Rectangle()
                .fill(.black.opacity(0.28))
                .frame(width: 1, height: 22)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.black.opacity(0.15), lineWidth: 0.5)
        )
    }

    /// Logo du réseau : pastille lisible pour Visa/Amex/Discover, deux
    /// disques entrelacés pour Mastercard. `.unknown` n'affiche rien.
    @ViewBuilder
    private var networkLogo: some View {
        switch network {
        case .mastercard:
            HStack(spacing: -10) {
                Circle().fill(Color(hex: "#EB001B")).frame(width: 26, height: 26)
                Circle().fill(Color(hex: "#F79E1B").opacity(0.9)).frame(width: 26, height: 26)
            }
        case .visa, .amex, .discover:
            Text(network.label)
                .font(.footnote.weight(.heavy))
                .italic(network == .visa)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.white.opacity(0.18), in: Capsule())
        case .unknown:
            EmptyView()
        }
    }

    private func labelValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.caption.weight(.medium).monospaced())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Formatage du numéro

    private var displayedNumber: String {
        if let number = revealedNumber {
            return grouped(number.filter(\.isNumber), sizes: network.groupSizes)
        }
        let last = card.lastFour.isEmpty ? "••••" : card.lastFour
        return "•••• •••• •••• \(last)"
    }

    /// Regroupe les chiffres selon les tailles de blocs du réseau
    /// (4-6-5 pour Amex, 4-4-4-4 sinon). Les chiffres en trop sont
    /// ajoutés en fin de chaîne par blocs de 4.
    private func grouped(_ digits: String, sizes: [Int]) -> String {
        var groups: [String] = []
        var index = digits.startIndex
        for size in sizes {
            guard index < digits.endIndex else { break }
            let end = digits.index(index, offsetBy: size, limitedBy: digits.endIndex) ?? digits.endIndex
            groups.append(String(digits[index..<end]))
            index = end
        }
        // Reste éventuel (numéros à 19 chiffres) par blocs de 4.
        while index < digits.endIndex {
            let end = digits.index(index, offsetBy: 4, limitedBy: digits.endIndex) ?? digits.endIndex
            groups.append(String(digits[index..<end]))
            index = end
        }
        return groups.joined(separator: " ")
    }
}
