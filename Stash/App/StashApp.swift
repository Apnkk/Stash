import SwiftUI

@main
struct StashApp: App {
    @StateObject private var store = CardStore()
    @StateObject private var lock = AppLock()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if lock.isUnlocked {
                    CardListView()
                        .environmentObject(store)
                        .transition(.opacity)
                } else {
                    LockScreenView()
                        .environmentObject(lock)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: lock.isUnlocked)
            .preferredColorScheme(.dark)
            .onAppear { lock.unlockIfNeeded() }
        }
    }
}

/// Gère le verrouillage global de l'app par Face ID / Touch ID.
@MainActor
final class AppLock: ObservableObject {
    @Published var isUnlocked = false
    @Published var lastError: String?

    func unlockIfNeeded() {
        guard !isUnlocked else { return }
        BiometricAuth.authenticate(reason: "Déverrouille Stash pour accéder à tes cartes.") { [weak self] result in
            switch result {
            case .success:
                self?.isUnlocked = true
                self?.lastError = nil
            case .failed(let message):
                self?.lastError = message
            }
        }
    }
}
