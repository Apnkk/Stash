import SwiftUI

/// Rendu physique haut de gamme d'une carte bancaire : dégradé titane/luxe,
/// puce EMV dorée avec micro-gravures, symbole sans-contact NFC,
/// logo de réseau net, numéro formaté par blocs avec frappe métallique, titulaire et expiration.
struct RealisticCardView: View {
    let card: Card
    /// Numéro complet déjà déchiffré, ou `nil` pour l'affichage masqué.
    var revealedNumber: String? = nil
    /// Image de fond injectée pour l'aperçu direct (formulaire). Si `nil`, on
    /// charge l'image persistée via `ArtVault` quand `card.hasCustomArt`.
    var artOverride: UIImage? = nil

    /// Image de fond effective : l'override d'aperçu prime, sinon celle stockée.
    private var backgroundArt: UIImage? {
        if let artOverride { return artOverride }
        guard card.hasCustomArt else { return nil }
        return ArtVault.load(card.id.uuidString)
    }

    /// Réseau à utiliser pour l'apparence : d'abord celui figé à la saisie,
    /// sinon détecté depuis le numéro révélé s'il est fourni.
    private var network: CardNetwork {
        if card.network != .unknown {
            return card.network
        }
        if let number = revealedNumber {
            return CardNetwork.detect(from: number)
        }
        return .unknown
    }

    /// L'utilisateur a-t-il gardé la couleur par défaut ?
    private var usesDefaultColor: Bool {
        card.colorHex.uppercased() == "#D62836" || card.colorHex.isEmpty
    }

    /// L'utilisateur a-t-il choisi un réseau manuellement ?
    private var hasManualNetwork: Bool {
        CardNetwork(rawValue: card.manualNetworkRaw).map { $0 != .unknown } ?? false
    }

    /// Couleurs du dégradé de fond de la carte.
    private var gradientColors: [Color] {
        if usesDefaultColor {
            // Un design de réseau choisi à la main prime sur la banque détectée.
            if hasManualNetwork, network != .unknown {
                return network.brandColors.map { Color(hex: $0) }
            }
            // Priorité aux couleurs de la banque détectée (persistées).
            if !card.bankColorHex.isEmpty {
                let base = Color(hex: card.bankColorHex)
                return [base.opacity(0.95), base.opacity(0.70), Color(hex: "#0c0e14")]
            }
            // Réseau détecté
            if network != .unknown {
                let netColors = network.brandColors.map { Color(hex: $0) }
                if netColors.count >= 2 { return netColors }
                if let first = netColors.first { return [first, first.opacity(0.75)] }
            }
            // Défaut : Noir Titane / Satin Space Black luxueux (au lieu du rouge plat)
            return [
                Color(hex: "#262b36"),
                Color(hex: "#161922"),
                Color(hex: "#0c0e14")
            ]
        }
        let base = Color(hex: card.colorHex)
        return [base.opacity(0.95), base.opacity(0.65), Color(hex: "#0b0d13")]
    }

    var body: some View {
        ZStack {
            // 1. Fond dégradé de base
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 2. Visuel CardArt ou photo personnalisée
            if let design = CardDesign.find(card.designID) {
                design.image
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.10),
                                Color.black.opacity(0.45)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .allowsHitTesting(false)
            } else if let backgroundArt {
                Image(uiImage: backgroundArt)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.15),
                                Color.black.opacity(0.50)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .allowsHitTesting(false)
            }

            // 3. Reflet biseauté & brillance spéculaire authentique
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .allowsHitTesting(false)

            // 4. Bordure fine chanfreinée
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.08),
                            Color.clear,
                            Color.black.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)

            // 5. Contenu textuel et symboles de la carte
            VStack(alignment: .leading, spacing: 0) {
                // Ligne du haut : Nom / Banque + Logo Réseau
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                            .lineLimit(1)

                        if !card.bankName.isEmpty {
                            Text(card.bankName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    networkLogo
                }

                Spacer(minLength: 6)

                // Ligne médiane : Puce EMV 3D + Symbole sans contact NFC
                HStack(spacing: 12) {
                    chipView

                    Image(systemName: "wave.3.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .rotationEffect(.degrees(90))
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)

                    Spacer()
                }
                .padding(.top, 4)

                Spacer(minLength: 8)

                // Numéro de carte avec effet de frappe métallique
                Text(displayedNumber)
                    .font(.system(size: 19, weight: .bold, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)

                Spacer(minLength: 8)

                // Ligne du bas : Titulaire & Expiration
                HStack(alignment: .bottom, spacing: 24) {
                    labelValue("TITULAIRE", card.holder.isEmpty ? "—" : card.holder.uppercased())
                    labelValue("EXPIRE FIN", card.expiry.isEmpty ? "MM/AA" : card.expiry)
                    Spacer()
                }
            }
            .padding(18)
        }
        .frame(height: 205)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 8)
    }

    // MARK: - Composants Visuels

    /// Puce EMV réaliste avec dorure brossée et micro-gravures.
    private var chipView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#F5DF88"),
                            Color(hex: "#C89E28"),
                            Color(hex: "#A37D18")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 32)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

            // Gravures des micro-contacts
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.black.opacity(0.35))
                        .frame(height: 0.8)
                }
            }
            .frame(width: 32)

            Rectangle()
                .fill(Color.black.opacity(0.35))
                .frame(width: 0.8, height: 20)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
        )
    }

    /// Logo du réseau bancaire : design moderne et fidèle.
    @ViewBuilder
    private var networkLogo: some View {
        switch network {
        case .mastercard:
            HStack(spacing: -9) {
                Circle().fill(Color(hex: "#EB001B")).frame(width: 24, height: 24)
                Circle().fill(Color(hex: "#F79E1B").opacity(0.92)).frame(width: 24, height: 24)
            }
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        case .visa:
            Text("VISA")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .italic()
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        case .amex:
            Text("AMEX")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(hex: "#006FCF"), in: RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        case .discover:
            Text("DISCOVER")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(hex: "#FF6600"), in: RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        case .unknown:
            EmptyView()
        }
    }

    private func labelValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 7.5, weight: .bold))
                .foregroundStyle(.white.opacity(0.65))
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
            Text(value)
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
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

    private func grouped(_ digits: String, sizes: [Int]) -> String {
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
}
