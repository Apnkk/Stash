import SwiftUI
import UIKit

/// Mode présentation plein écran pour passage en caisse.
///
/// Optimise le scan laser en magasin :
/// - Luminosité d'écran poussée au maximum (100 %)
/// - Mise en veille automatique désactivée (`isIdleTimerDisabled = true`)
/// - Fond sombre immersif antireflet
/// - Code-barres ou QR agrandi au maximum avec option de rotation à 90°
/// - Restauration automatique des réglages à la fermeture
struct PresentationModeView: View {
    @Environment(\.dismiss) private var dismiss

    let card: Card
    let barcodeImage: UIImage?

    @State private var isRotated = false
    @State private var copied = false
    @State private var previousBrightness = activeScreen.brightness

    private static var activeScreen: UIScreen {
        let scenes = UIApplication.shared.connectedScenes
        if let windowScene = scenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? scenes.compactMap({ $0 as? UIWindowScene }).first {
            return windowScene.screen
        }
        return UIScreen.screens.first ?? UIScreen.main
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Barre supérieure : Titre et bouton de fermeture
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Mode passage en caisse")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()

                    Button {
                        Haptics.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8), .white.opacity(0.2))
                    }
                    .accessibilityLabel("Fermer le mode caisse")
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Conteneur du code-barres / QR
                VStack(spacing: 20) {
                    if let image = barcodeImage {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: .white.opacity(0.15), radius: 24, x: 0, y: 8)

                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .padding(24)
                                .rotationEffect(.degrees(isRotated ? 90 : 0))
                                .animation(Motion.snappy, value: isRotated)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .padding(.horizontal, 20)
                    } else {
                        // Fallback si l'image n'a pas pu être rendue
                        Text(card.code)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding()
                    }

                    // Bouton de rotation si code-barres 1D
                    if card.format != .qr && card.format != .aztec {
                        Button {
                            Haptics.selection()
                            isRotated.toggle()
                        } label: {
                            Label(
                                isRotated ? "Position verticale" : "Pivoter pour scanner",
                                systemImage: "arrow.triangle.2.circlepath"
                            )
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.12), in: Capsule())
                        }
                    }
                }

                Spacer()

                // Numéro sous le code avec copie rapide
                VStack(spacing: 8) {
                    Text(card.code)
                        .font(.system(size: 26, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.horizontal, 20)

                    Button {
                        Haptics.success()
                        UIPasteboard.general.string = card.code
                        withAnimation(Motion.snappy) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(Motion.snappy) { copied = false }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copié !" : "Copier le numéro")
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(copied ? .green : .white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            let screen = Self.activeScreen
            previousBrightness = screen.brightness
            screen.brightness = 1.0
            UIApplication.shared.isIdleTimerDisabled = true
            Haptics.medium()
        }
        .onDisappear {
            Self.activeScreen.brightness = previousBrightness
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
