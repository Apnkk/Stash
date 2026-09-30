import SwiftUI

@main
struct StashApp: App {
    @StateObject private var store = CardStore()
    @StateObject private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase

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
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    // Reverrouille dès que l'app quitte l'écran : au retour,
                    // Face ID / Touch ID sera de nouveau exigé.
                    lock.lock()
                case .active:
                    lock.unlockIfNeeded()
                default:
                    break
                }
            }
        }
    }
}

/// Gère le verrouillage global de l'app par Face ID / Touch ID.
@MainActor
final class AppLock: ObservableObject {
    @Published var isUnlocked = false
    @Published var lastError: String?

    /// Empêche de relancer une authentification déjà en cours.
    private var isAuthenticating = false

    func unlockIfNeeded() {
        guard !isUnlocked, !isAuthenticating else { return }
        isAuthenticating = true
        BiometricAuth.authenticate(reason: "Déverrouille Stash pour accéder à tes cartes.") { [weak self] result in
            self?.isAuthenticating = false
            switch result {
            case .success:
                self?.isUnlocked = true
                self?.lastError = nil
            case .failed(let message):
                self?.lastError = message
            }
        }
    }

    /// Reverrouille l'app (au passage en arrière-plan).
    func lock() {
        isUnlocked = false
        lastError = nil
    }
}
