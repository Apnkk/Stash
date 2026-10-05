import SwiftUI

/// Écran de verrouillage affiché tant que l'authentification n'a pas réussi.
struct LockScreenView: View {
    @EnvironmentObject private var lock: AppLock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                .symbolEffect(.bounce, value: lock.lastError)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 10) {
                Text("Stash est verrouillé")
                    .font(.title2.weight(.bold))

                Text("Authentifie-toi pour accéder à tes cartes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .opacity(appeared ? 1 : 0)

            if let error = lock.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                Haptics.medium()
                lock.unlockIfNeeded()
            } label: {
                Label("Déverrouiller", systemImage: "faceid")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .glassProminentButtonIfAvailable()
            .pressable()
            .padding(.top, 8)
            .opacity(appeared ? 1 : 0)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .animation(Motion.snappy, value: lock.lastError)
        .onAppear {
            withAnimation(reduceMotion ? Motion.fade : Motion.soft) { appeared = true }
        }
    }
}
