import SwiftUI

/// Écran de verrouillage affiché tant que l'authentification n'a pas réussi.
struct LockScreenView: View {
    @EnvironmentObject private var lock: AppLock

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Stash est verrouillé")
                .font(.title2.weight(.bold))

            Text("Authentifie-toi pour accéder à tes cartes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let error = lock.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                lock.unlockIfNeeded()
            } label: {
                Label("Déverrouiller", systemImage: "faceid")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .glassProminentButtonIfAvailable()
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
