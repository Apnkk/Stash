import SwiftUI

/// Rendu physique d'une carte bancaire au format ISO/IEC 7810 ID-1 (ratio 1,586).
///
/// Deux modes de rendu :
/// - **Visuel** (design CardArt ou image importée) : l'image EST la carte, comme
///   dans Apple Wallet. On n'ajoute par-dessus que les 4 derniers chiffres (ou le
///   numéro révélé) sur un voile discret : le visuel contient déjà logo, puce et
///   réseau, les redessiner créerait des doublons.
/// - **Généré** (pas de visuel) : dégradé de marque, puce EMV, sans-contact,
///   logo réseau, numéro, titulaire et expiration.
///
/// Toutes les dimensions internes sont proportionnelles à la largeur : la carte
/// garde exactement les mêmes proportions en vignette, en pile ou en plein écran.
struct RealisticCardView: View {
    let card: Card
    /// Numéro complet déjà déchiffré, ou `nil` pour l'affichage masqué.
    var revealedNumber: String? = nil
    /// Image de fond injectée pour l'aperçu direct (formulaire). Si `nil`, on
    /// charge l'image persistée via `ArtVault` quand `card.hasCustomArt`.
    var artOverride: UIImage? = nil
    /// Active l'inclinaison 3D au doigt. Désactivé par défaut : dans une liste
    /// ou un bouton, un geste de glissement bloquerait le tap et le défilement.
    var enableTilt: Bool = false
    /// Force l'affichage ou le masquage de la puce EMV (aperçu du CardArt Studio).
    var showChipOverride: Bool? = nil

    /// Ratio largeur / hauteur d'une carte bancaire réelle (85,60 × 53,98 mm).
    static let aspectRatio: CGFloat = 1.586

    /// Largeur de référence sur laquelle les tailles internes sont calibrées.
    private static let referenceWidth: CGFloat = 340

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGSize = .zero
    @State private var isInteracting = false

    // MARK: - Valeurs dérivées

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }

    /// Image de fond effective : l'override d'aperçu prime, sinon celle stockée.
    private var backgroundArt: UIImage? {
        if let artOverride { return artOverride }
        guard card.hasCustomArt else { return nil }
        return ArtVault.load(card.id.uuidString)
    }

    private var design: CardDesign? {
        CardDesign.find(card.designID)
    }

    /// La carte est-elle habillée d'un visuel (design intégré ou image) ?
    private var hasArt: Bool {
        design != nil || backgroundArt != nil
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

    private var effectiveShowChip: Bool {
        showChipOverride ?? card.showChip
    }

    /// L'utilisateur a-t-il gardé la couleur par défaut ?
    private var usesDefaultColor: Bool {
        card.colorHex.uppercased() == "#D62836" || card.colorHex.isEmpty
    }

    /// L'utilisateur a-t-il choisi un réseau manuellement ?
    private var hasManualNetwork: Bool {
        CardNetwork(rawValue: card.manualNetworkRaw).map { $0 != .unknown } ?? false
    }

    /// Couleurs du dégradé de fond de la carte générée.
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
            if network != .unknown {
                let netColors = network.brandColors.map { Color(hex: $0) }
                if netColors.count >= 2 { return netColors }
                if let first = netColors.first { return [first, first.opacity(0.75)] }
            }
            // Défaut : noir titane satiné.
            return [Color(hex: "#2a2f3b"), Color(hex: "#171a22"), Color(hex: "#0b0d12")]
        }
        let base = Color(hex: card.colorHex)
        return [base.opacity(0.95), base.opacity(0.65), Color(hex: "#0b0d13")]
    }

    // MARK: - Inclinaison 3D

    private var tiltActive: Bool { enableTilt && !reduceMotion }

    /// Inclinaison verticale (pitch) en degrés, bornée.
    private var pitchDegrees: Double {
        let normalized = Double(-dragOffset.height) / 90
        return min(max(normalized * 10, -10), 10)
    }

    /// Inclinaison horizontale (roll) en degrés, bornée.
    private var rollDegrees: Double {
        let normalized = Double(dragOffset.width) / 90
        return min(max(normalized * 12, -12), 12)
    }

    /// Position du reflet, synchronisée avec l'angle de vue.
    private var sheenLocation: Double {
        let shift = (rollDegrees / 30) - (pitchDegrees / 40)
        return min(max(0.35 + shift, 0.05), 0.9)
    }

    // MARK: - Corps

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / Self.referenceWidth
            ZStack {
                background
                if hasArt {
                    artOverlay(scale: s)
                } else {
                    generatedContent(scale: s)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .clipShape(shape)
        .overlay(sheen.clipShape(shape).allowsHitTesting(false))
        .overlay(bevel.allowsHitTesting(false))
        .shadow(
            color: .black.opacity(isInteracting ? 0.5 : 0.35),
            radius: isInteracting ? 20 : 12,
            x: CGFloat(rollDegrees * 0.4),
            y: CGFloat(7 - pitchDegrees * 0.4)
        )
        .rotation3DEffect(.degrees(pitchDegrees), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .rotation3DEffect(.degrees(rollDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .scaleEffect(isInteracting ? 1.02 : 1)
        .animation(
            isInteracting ? .interactiveSpring(response: 0.25, dampingFraction: 0.8) : Motion.spring,
            value: dragOffset
        )
        .gesture(
            tiltActive ? DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isInteracting = true
                    dragOffset = value.translation
                }
                .onEnded { _ in
                    isInteracting = false
                    dragOffset = .zero
                } : nil
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Fond

    @ViewBuilder
    private var background: some View {
        if let design {
            // `Color.clear` fixe la taille : l'image remplit sans jamais agrandir
            // la carte (sinon le texte se retrouvait rogné en haut et en bas).
            Color.clear
                .overlay { design.image.resizable().scaledToFill() }
                .clipped()
        } else if let backgroundArt {
            Color.clear
                .overlay { Image(uiImage: backgroundArt).resizable().scaledToFill() }
                .clipped()
        } else {
            ZStack {
                LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                // Halo de lumière en haut à gauche : donne du volume à la matière.
                RadialGradient(
                    colors: [.white.opacity(0.14), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 320
                )
                // Grand arc décoratif très discret, signature des cartes premium.
                Circle()
                    .stroke(.white.opacity(0.05), lineWidth: 36)
                    .scaleEffect(1.5)
                    .offset(x: 150, y: 90)
            }
        }
    }

    /// Reflet spéculaire : discret au repos, il balaie la carte quand on l'incline.
    private var sheen: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(isInteracting ? 0.22 : 0.08), location: sheenLocation),
                .init(color: .clear, location: min(sheenLocation + 0.25, 1)),
                .init(color: .clear, location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Liseré chanfreiné : lumière zénithale en haut, ombre en bas.
    private var bevel: some View {
        shape.strokeBorder(
            LinearGradient(
                colors: [.white.opacity(0.35), .white.opacity(0.08), .clear, .black.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 1
        )
    }

    // MARK: - Mode visuel

    /// Sur un visuel, seules les infos absentes de l'image sont ajoutées :
    /// le numéro (masqué ou révélé) et, une fois révélé, titulaire et expiration.
    private func artOverlay(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            Spacer(minLength: 0)
            if revealedNumber != nil {
                Text(displayedNumber)
                    .font(.system(size: 18 * s, weight: .semibold, design: .monospaced))
                    .tracking(1.2 * s)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 18 * s) {
                    if !card.holder.isEmpty { Text(card.holder.uppercased()) }
                    if !card.expiry.isEmpty { Text(card.expiry) }
                }
                .font(.system(size: 11 * s, weight: .medium, design: .monospaced))
                .opacity(0.85)
                .lineLimit(1)
            } else {
                Text("•••• \(card.lastFour.isEmpty ? "••••" : card.lastFour)")
                    .font(.system(size: 14 * s, weight: .semibold, design: .monospaced))
                    .tracking(1 * s)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(16 * s)
        .background(alignment: .bottom) {
            // Voile bas uniquement : garde le numéro lisible sans assombrir le visuel.
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .frame(height: 70 * s * (revealedNumber != nil ? 1.4 : 1))
        }
    }

    // MARK: - Mode généré

    private func generatedContent(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ligne du haut : nom / banque + logo réseau
            HStack(alignment: .top, spacing: 8 * s) {
                VStack(alignment: .leading, spacing: 2 * s) {
                    Text(card.name)
                        .font(.system(size: 15 * s, weight: .bold))
                        .lineLimit(1)
                    if !card.bankName.isEmpty, card.bankName != card.name {
                        Text(card.bankName)
                            .font(.system(size: 11 * s, weight: .medium))
                            .opacity(0.75)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            Text(displayedNumber)
                .font(.system(size: 19 * s, weight: .semibold, design: .monospaced))
                .tracking(1.6 * s)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 24 * s) {
                labelValue("TITULAIRE", card.holder.isEmpty ? "—" : card.holder.uppercased(), scale: s)
                labelValue("EXPIRE FIN", card.expiry.isEmpty ? "MM/AA" : card.expiry, scale: s)
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
        .padding(18 * s)
    }

    /// Puce EMV dorée avec micro-contacts.
    private func chipView(scale s: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6 * s, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#F5DF88"), Color(hex: "#C89E28"), Color(hex: "#A37D18")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(spacing: 6 * s) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle().fill(.black.opacity(0.3)).frame(height: 0.8)
                }
            }
            .padding(.horizontal, 5 * s)
            Rectangle()
                .fill(.black.opacity(0.3))
                .frame(width: 0.8)
                .padding(.vertical, 6 * s)
        }
        .frame(width: 42 * s, height: 31 * s)
        .overlay(
            RoundedRectangle(cornerRadius: 6 * s, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
        )
    }

    /// Logo du réseau bancaire.
    @ViewBuilder
    private func networkLogo(scale s: CGFloat) -> some View {
        switch network {
        case .mastercard:
            HStack(spacing: -9 * s) {
                Circle().fill(Color(hex: "#EB001B")).frame(width: 24 * s, height: 24 * s)
                Circle().fill(Color(hex: "#F79E1B").opacity(0.92)).frame(width: 24 * s, height: 24 * s)
            }
        case .visa:
            Text("VISA")
                .font(.system(size: 18 * s, weight: .black))
                .italic()
                .tracking(-0.5)
        case .amex:
            Text("AMEX")
                .font(.system(size: 12 * s, weight: .heavy))
                .padding(.horizontal, 7 * s)
                .padding(.vertical, 3 * s)
                .background(Color(hex: "#006FCF"), in: RoundedRectangle(cornerRadius: 5 * s))
        case .discover:
            Text("DISCOVER")
                .font(.system(size: 11 * s, weight: .heavy))
                .padding(.horizontal, 7 * s)
                .padding(.vertical, 3 * s)
                .background(Color(hex: "#FF6600"), in: RoundedRectangle(cornerRadius: 5 * s))
        case .unknown:
            EmptyView()
        }
    }

    private func labelValue(_ label: String, _ value: String, scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2 * s) {
            Text(label)
                .font(.system(size: 7.5 * s, weight: .bold))
                .opacity(0.65)
            Text(value)
                .font(.system(size: 12.5 * s, weight: .semibold, design: .monospaced))
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

    private var accessibilityDescription: String {
        let last = card.lastFour.isEmpty ? "" : ", se terminant par \(card.lastFour)"
        let net = network == .unknown ? "" : ", \(network.label)"
        return "\(card.name)\(net)\(last)"
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
