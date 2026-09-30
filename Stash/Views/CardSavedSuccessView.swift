import SwiftUI

/// Écran de célébration affiché brièvement après l'enregistrement réussi
/// d'une carte. Une coche se dessine dans un cercle qui pulse, entourée d'un
/// halo et de quelques particules, avec un retour haptique de succès.
///
/// L'écran se referme tout seul après un court délai (ou au tap) en appelant
/// `onFinished`, ce qui laisse ensuite le flux normal reprendre la main
/// (fermeture des feuilles + mise en avant de la carte à l'accueil).
struct CardSavedSuccessView: View {
    /// Nom de la carte tout juste enregistrée (affiché sous la coche).
    let cardName: String
    /// Appelé quand la célébration est terminée (auto ou tap).
    let onFinished: () -> Void

    /// Délai avant fermeture automatique.
    private let autoDismissAfter: TimeInterval = 1.6

    // États d'animation, déclenchés en cascade à l'apparition.
    @State private var circleScale: CGFloat = 0.4
    @State private var circleOpacity: Double = 0
    @State private var checkProgress: CGFloat = 0
    @State private var haloScale: CGFloat = 0.6
    @State private var haloOpacity: Double = 0
    @State private var textVisible = false
    @State private var burst = false
    @State private var finished = false

    /// Particules réparties en cercle autour de la coche.
    private let particles: [Particle] = Particle.ring(count: 12)

    var body: some View {
        ZStack {
            // Fond sombre translucide qui recouvre tout.
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 24) {
                ZStack {
                    // Halo lumineux qui se diffuse.
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.stashRed.opacity(0.5), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 130
                            )
                        )
                        .frame(width: 240, height: 240)
                        .scaleEffect(haloScale)
                        .opacity(haloOpacity)

                    // Particules qui jaillissent du centre.
                    ForEach(particles) { particle in
                        Circle()
                            .fill(particle.color)
                            .frame(width: particle.size, height: particle.size)
                            .offset(
                                x: burst ? particle.offset.width : 0,
                                y: burst ? particle.offset.height : 0
                            )
                            .opacity(burst ? 0 : 1)
                            .scaleEffect(burst ? 0.4 : 1)
                    }

                    // Cercle plein qui porte la coche.
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.stashRed, Color.stashRed.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.stashRed.opacity(0.5), radius: 20, y: 8)
                        .scaleEffect(circleScale)
                        .opacity(circleOpacity)
                        .overlay {
                            // La coche se dessine progressivement (trim).
                            CheckmarkShape()
                                .trim(from: 0, to: checkProgress)
                                .stroke(
                                    Color.white,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                                )
                                .frame(width: 56, height: 56)
                        }
                }
                .frame(height: 240)

                VStack(spacing: 6) {
                    Text("Carte ajoutée !")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text(cardName.isEmpty ? "Ta carte est dans ton portefeuille." : "« \(cardName) » est dans ton portefeuille.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .opacity(textVisible ? 1 : 0)
                .offset(y: textVisible ? 0 : 12)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Carte ajoutée. \(cardName)")
        .accessibilityAddTraits(.isButton)
        .onAppear(perform: runSequence)
    }

    /// Joue l'animation d'entrée en cascade puis programme la fermeture auto.
    private func runSequence() {
        Haptics.success()

        // 1. Le cercle éclot.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
            circleScale = 1
            circleOpacity = 1
        }

        // 2. Le halo se diffuse.
        withAnimation(.easeOut(duration: 0.6)) {
            haloScale = 1
            haloOpacity = 1
        }

        // 3. La coche se dessine, légèrement après le cercle.
        withAnimation(.easeInOut(duration: 0.4).delay(0.2)) {
            checkProgress = 1
        }

        // 4. Les particules jaillissent.
        withAnimation(.easeOut(duration: 0.7).delay(0.15)) {
            burst = true
        }

        // 5. Le texte apparaît.
        withAnimation(.easeOut(duration: 0.35).delay(0.35)) {
            textVisible = true
        }

        // 6. Le halo redescend doucement pour ne pas rester envahissant.
        withAnimation(.easeInOut(duration: 0.8).delay(0.6)) {
            haloOpacity = 0.35
        }

        // Fermeture automatique.
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissAfter) {
            finish()
        }
    }

    /// Termine la célébration une seule fois (auto ou tap).
    private func finish() {
        guard !finished else { return }
        finished = true
        onFinished()
    }
}

/// Forme d'une coche (checkmark) dessinable et animable via `trim`.
private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Points relatifs à la boîte, calibrés pour une coche équilibrée.
        let start = CGPoint(x: rect.width * 0.18, y: rect.height * 0.52)
        let mid = CGPoint(x: rect.width * 0.42, y: rect.height * 0.76)
        let end = CGPoint(x: rect.width * 0.82, y: rect.height * 0.28)
        path.move(to: start)
        path.addLine(to: mid)
        path.addLine(to: end)
        return path
    }
}

/// Une particule de la « gerbe » de confettis autour de la coche.
private struct Particle: Identifiable {
    let id = UUID()
    let offset: CGSize
    let size: CGFloat
    let color: Color

    /// Répartit `count` particules en anneau autour du centre, avec des
    /// tailles et couleurs légèrement variées pour un rendu vivant.
    static func ring(count: Int) -> [Particle] {
        let palette: [Color] = [
            .stashRed,
            Color(hex: "#F5A623"),
            Color(hex: "#4A90E2"),
            Color(hex: "#7ED321"),
            .white
        ]
        return (0..<count).map { index in
            let angle = (Double(index) / Double(count)) * 2 * .pi
            let radius: CGFloat = CGFloat.random(in: 90...130)
            return Particle(
                offset: CGSize(
                    width: cos(angle) * radius,
                    height: sin(angle) * radius
                ),
                size: CGFloat.random(in: 6...12),
                color: palette[index % palette.count]
            )
        }
    }
}
