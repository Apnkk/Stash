import SwiftUI
import UIKit

/// Système d'animation partagé de Stash.
///
/// Centralise les courbes, durées et transitions pour garantir un rendu
/// cohérent, fluide et premium dans toute l'app. On s'appuie de préférence
/// sur des ressorts (`spring`) : ils donnent un mouvement naturel et
/// interruptible, idéal pour une UI qui doit rester réactive.
enum Motion {

    // MARK: - Courbes réutilisables

    /// Ressort standard : transitions d'écran, apparitions, réordonnancements.
    static let standard: Animation = .spring(response: 0.42, dampingFraction: 0.82)

    /// Ressort doux : grands mouvements (empilement de cartes, onboarding).
    static let soft: Animation = .spring(response: 0.6, dampingFraction: 0.85)

    /// Ressort vif : retours au toucher, petits éléments (boutons, pastilles).
    static let snappy: Animation = .spring(response: 0.3, dampingFraction: 0.72)

    /// Ressort rebondissant : effets ludiques ponctuels (validation, succès).
    static let bouncy: Animation = .spring(response: 0.45, dampingFraction: 0.6)

    /// Ressort interactif fluide, optimisé pour les piles de cartes Wallet.
    static let spring: Animation = .spring(response: 0.38, dampingFraction: 0.8)

    /// Fondu simple, pour les changements d'opacité discrets.
    static let fade: Animation = .easeInOut(duration: 0.25)

    /// Applique un délai à une animation, pour cascader des apparitions.
    static func staggered(_ base: Animation = standard, index: Int, step: Double = 0.06) -> Animation {
        base.delay(Double(index) * step)
    }
}

// MARK: - Transitions personnalisées

extension AnyTransition {

    /// Apparition « carte » : glisse depuis le bas avec un léger fondu et
    /// une mise à l'échelle. Idéale pour les tuiles de la liste.
    static var cardAppear: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.94, anchor: .bottom)),
            removal: .opacity.combined(with: .scale(scale: 0.96))
        )
    }

    /// Apparition verticale douce avec fondu (panneaux, sections).
    static var riseAndFade: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }

    /// Zoom + fondu, pour les éléments qui doivent « éclore » au centre.
    static var popIn: AnyTransition {
        .scale(scale: 0.85).combined(with: .opacity)
    }
}

// MARK: - Retours haptiques

/// Fabrique de retours haptiques, centralisée pour un ressenti cohérent.
///
/// Les générateurs sont préparés (`prepare()`) juste avant usage pour
/// réduire la latence, comme recommandé par UIKit.
enum Haptics {

    /// Impact léger : sélection d'une couleur, tap sur une tuile.
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Impact moyen : ouverture d'une carte, bouton principal.
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Impact rigide : action ferme (verrouiller, masquer).
    static func rigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Notification de succès (enregistrement, révélation réussie).
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Notification d'erreur (validation échouée, authentification refusée).
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    /// Changement de sélection (segmented control, réordonnancement).
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

// MARK: - Modificateurs réutilisables

/// Effet d'enfoncement au toucher : l'élément se réduit et se ternit
/// légèrement pendant l'appui, avec un retour ressort. Réutilisable sur
/// n'importe quelle vue interactive pour un ressenti « premium ».
struct PressableModifier: ViewModifier {
    var scale: CGFloat = 0.96
    var haptic: Bool = true

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? scale : 1)
            .opacity(isPressed ? 0.9 : 1)
            .animation(Motion.snappy, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            if haptic { Haptics.light() }
                        }
                    }
                    .onEnded { _ in isPressed = false }
            )
    }
}

/// Apparition en cascade : l'élément monte et se révèle avec un délai
/// proportionnel à son index, pour animer une liste au chargement.
struct AppearTransitionModifier: ViewModifier {
    let index: Int
    var step: Double = 0.06

    @State private var visible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 16)
            .onAppear {
                if reduceMotion {
                    withAnimation(Motion.fade) { visible = true }
                } else {
                    // Plafonne le délai pour que les longues listes ne mettent pas des secondes à apparaître.
                    let cappedIndex = min(index, 8)
                    withAnimation(Motion.staggered(Motion.soft, index: cappedIndex, step: step)) {
                        visible = true
                    }
                }
            }
    }
}

extension View {

    /// Rend une vue « pressable » (effet d'enfoncement + haptique légère).
    func pressable(scale: CGFloat = 0.96, haptic: Bool = true) -> some View {
        modifier(PressableModifier(scale: scale, haptic: haptic))
    }

    /// Anime l'apparition d'un élément de liste en cascade selon son index.
    func appearInCascade(index: Int, step: Double = 0.06) -> some View {
        modifier(AppearTransitionModifier(index: index, step: step))
    }
}
