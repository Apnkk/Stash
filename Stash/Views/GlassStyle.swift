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
    /// - Parameter cornerRadius: rayon d'arrondi du verre.
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
