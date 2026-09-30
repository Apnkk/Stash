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
                    // On note l'heure de départ ; le reverrouillage effectif
                    // n'aura lieu qu'au retour si le délai de grâce est dépassé
                    // (évite de redemander Face ID après une feuille de partage,
                    // un sélecteur de fichiers pour l'import/export, etc.).
                    lock.enterBackground()
                case .active:
                    lock.applyAutoLockIfNeeded()
                    lock.unlockIfNeeded()
                default:
                    break
                }
            }
        }
    }
}

/// Délai de grâce avant que l'app ne se reverrouille automatiquement
/// après un passage en arrière-plan.
enum AutoLockDelay: Int, CaseIterable, Identifiable {
    case immediate = 0
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .immediate:     return "Immédiat"
        case .thirtySeconds: return "Après 30 secondes"
        case .oneMinute:     return "Après 1 minute"
        case .fiveMinutes:   return "Après 5 minutes"
        }
    }

    /// Clé de persistance partagée entre l'écran Réglages et AppLock.
    static let storageKey = "autoLockDelay"
}

/// Gère le verrouillage global de l'app par Face ID / Touch ID.
@MainActor
final class AppLock: ObservableObject {
    @Published var isUnlocked = false
    @Published var lastError: String?

    /// Empêche de relancer une authentification déjà en cours.
    private var isAuthenticating = false

    /// Instant du dernier passage en arrière-plan (nil si l'app est active).
    private var backgroundedAt: Date?

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

    /// Mémorise l'heure de passage en arrière-plan. Si le délai configuré est
    /// « Immédiat », on reverrouille tout de suite.
    func enterBackground() {
        backgroundedAt = Date()
        if currentDelay == .immediate {
            lock()
        }
    }

    /// Au retour au premier plan : reverrouille si le temps passé en
    /// arrière-plan dépasse le délai de grâce choisi par l'utilisateur.
    func applyAutoLockIfNeeded() {
        defer { backgroundedAt = nil }
        guard isUnlocked, let since = backgroundedAt else { return }
        let delay = currentDelay
        if delay == .immediate { lock(); return }
        if Date().timeIntervalSince(since) >= Double(delay.rawValue) {
            lock()
        }
    }

    /// Délai de grâce actuellement configuré (persisté dans UserDefaults).
    private var currentDelay: AutoLockDelay {
        // Au tout premier lancement, aucune valeur n'est stockée : on applique
        // le défaut raisonnable de 30 s plutôt que le 0 (.immediate) que
        // `integer(forKey:)` renverrait.
        guard UserDefaults.standard.object(forKey: AutoLockDelay.storageKey) != nil else {
            return .thirtySeconds
        }
        let raw = UserDefaults.standard.integer(forKey: AutoLockDelay.storageKey)
        return AutoLockDelay(rawValue: raw) ?? .thirtySeconds
    }

    /// Reverrouille l'app.
    func lock() {
        isUnlocked = false
        lastError = nil
    }
}
