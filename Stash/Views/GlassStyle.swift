import SwiftUI

/// Modificateurs Liquid Glass (iOS 26+) avec repli propre sur les versions antérieures.
/// Le vrai effet Liquid Glass n'apparaît que sur iOS 26 ; en dessous, on retombe
/// sur les styles système classiques (.borderedProminent / .bordered / matériaux).
extension View {

    /// Bouton en verre (barre d'outils, actions secondaires).
    @ViewBuilder
    func glassButtonIfAvailable() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Bouton principal en verre proéminent (call-to-action).
    @ViewBuilder
    func glassProminentButtonIfAvailable() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Applique un fond en verre sur un conteneur (carte, panneau).
    /// - Parameters:
    ///   - cornerRadius: rayon d'arrondi du verre.
    ///   - tint: teinte optionnelle du verre.
    ///   - interactive: le verre réagit au toucher (iOS 26).
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat = 16, tint: Color? = nil, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26, *) {
            self.glassEffect(Self.makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(tint?.opacity(0.35) ?? .clear, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
        }
    }

    /// Pastille en verre (filtres, badges). Réactive au toucher par défaut.
    @ViewBuilder
    func glassCapsule(tint: Color? = nil, interactive: Bool = true) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(Self.makeGlass(tint: tint, interactive: interactive), in: Capsule())
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .background(tint ?? .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
        }
    }

    /// Liseré de verre pour une surface déjà habillée (visuel de carte) :
    /// reflet zénithal + arête lumineuse, sans voiler l'image.
    func glassEdge(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .overlay(
                shape
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.16), .clear],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.45)
                        )
                    )
                    .allowsHitTesting(false)
            )
            .overlay(
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.08), .clear, .white.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
    }

    @available(iOS 26, *)
    private static func makeGlass(tint: Color?, interactive: Bool) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}