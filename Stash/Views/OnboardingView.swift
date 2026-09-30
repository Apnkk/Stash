import SwiftUI

/// Écran de présentation affiché une seule fois, au premier lancement.
///
/// Objectif : donner envie, pas expliquer chaque bouton. On enchaîne
/// quelques pages illustrées d'une pile de cartes animée, avec un défilement
/// fluide, des transitions soignées et la possibilité de passer à tout moment.
/// L'état « déjà vu » est persisté via `@AppStorage`.
struct OnboardingView: View {

    /// Persistance : passe à `true` dès que l'utilisateur termine ou passe.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    /// Fermeture appelée à la fin (le parent retire la vue de la hiérarchie).
    var onFinish: () -> Void

    @State private var page = 0
    @State private var appeared = false

    /// Pages de présentation (contenu narratif, pas un tutoriel).
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "creditcard.fill",
            title: "Toutes tes cartes,\nau même endroit",
            subtitle: "Fidélité et bancaires réunies dans une app élégante, prête en un geste."
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            title: "Chiffrées\net privées",
            subtitle: "Tes numéros restent sur ton téléphone, protégés par Face ID. Rien ne part sur un serveur."
        ),
        OnboardingPage(
            icon: "barcode.viewfinder",
            title: "Scanne\nen caisse",
            subtitle: "Ton code de fidélité s'affiche en grand, lumineux, prêt à être lu instantanément."
        )
    ]

    var body: some View {
        ZStack {
            // Fond sombre avec halo rouge diffus, dans l'esprit de l'app.
            backgroundGradient

            VStack(spacing: 0) {
                // Bouton « Passer » toujours accessible.
                HStack {
                    Spacer()
                    Button("Passer") { finish() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }

                Spacer()

                // Pile de cartes animée en haut de chaque page.
                AnimatedCardStack(highlightIndex: page)
                    .frame(height: 240)
                    .padding(.bottom, 8)

                // Texte des pages, en pagination horizontale.
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageContent(pages[index])
                            .tag(index)
                            .padding(.horizontal, 32)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 180)
                .animation(Motion.standard, value: page)

                pageIndicator
                    .padding(.top, 8)

                Spacer()

                actionButton
                    .padding(.horizontal, 28)
                    .padding(.bottom, 36)
            }
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(Motion.soft.delay(0.1)) { appeared = true }
            }
        }
        .onChange(of: page) { _, _ in
            Haptics.selection()
        }
    }

    // MARK: - Sous-vues

    private var backgroundGradient: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [Color.stashRed.opacity(0.35), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private func pageContent(_ page: OnboardingPage) -> some View {
        VStack(spacing: 16) {
            Image(systemName: page.icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.stashRed)
                .transition(.popIn)

            Text(page.title)
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.stashRed : Color.white.opacity(0.25))
                    .frame(width: index == page ? 22 : 7, height: 7)
                    .animation(Motion.snappy, value: page)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        let isLast = page == pages.count - 1
        Button {
            if isLast {
                finish()
            } else {
                withAnimation(Motion.standard) { page += 1 }
            }
        } label: {
            Text(isLast ? "Commencer" : "Suivant")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .glassProminentButtonIfAvailable()
        .pressable()
    }

    // MARK: - Actions

    private func finish() {
        Haptics.medium()
        hasSeenOnboarding = true
        withAnimation(Motion.soft) {
            onFinish()
        }
    }
}

/// Contenu d'une page de présentation.
private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
}

/// Pile de cartes décorative et animée pour l'onboarding.
///
/// Trois cartes empilées en éventail ; celle mise en avant (`highlightIndex`)
/// remonte, se redresse et s'éclaircit. Le mouvement est piloté par un ressort
/// doux pour un rendu premium et interruptible.
private struct AnimatedCardStack: View {
    let highlightIndex: Int

    /// Dégradés distincts (rouge/bordeaux/noir) pour différencier les cartes.
    private let gradients: [[Color]] = [
        [Color(hex: "#E1394A"), Color(hex: "#9E1B26")],
        [Color(hex: "#B8232F"), Color(hex: "#7A1520")],
        [Color(hex: "#3A3A3C"), Color(hex: "#1C1C1E")]
    ]

    var body: some View {
        ZStack {
            ForEach((0..<3).reversed(), id: \.self) { index in
                cardShape(index: index)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cardShape(index: Int) -> some View {
        // Index normalisé par rapport à la carte mise en avant : 0 = devant.
        let relative = ((index - highlightIndex) + 3) % 3
        let isFront = relative == 0

        return RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: gradients[index % gradients.count],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 240, height: 150)
            .overlay(alignment: .topLeading) {
                miniChip
                    .padding(18)
            }
            .overlay(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.55))
                    .frame(width: 90, height: 8)
                    .padding(18)
            }
            .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
            .scaleEffect(isFront ? 1 : 0.9 - CGFloat(relative) * 0.02)
            .rotationEffect(.degrees(Double(relative) * 6 - 6))
            .offset(
                x: CGFloat(relative) * 14,
                y: CGFloat(relative) * 18 - (isFront ? 10 : 0)
            )
            .opacity(isFront ? 1 : 0.7)
            .zIndex(isFront ? 3 : Double(3 - relative))
            .animation(Motion.soft, value: highlightIndex)
    }

    /// Puce EMV dorée miniature, cohérente avec le reste de l'app.
    private var miniChip: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#E7C766"), Color(hex: "#B8912F")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 40, height: 30)
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(.black.opacity(0.15), lineWidth: 0.5)
            )
    }
}
