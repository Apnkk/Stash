import Foundation
import LocalAuthentication

/// Authentification biométrique (Face ID / Touch ID) avec repli code d'accès.
enum BiometricAuth {

    /// Résultat lisible d'une tentative d'authentification.
    enum AuthResult {
        case success
        case failed(String)
    }

    /// Demande une authentification à l'utilisateur.
    /// - Parameter reason: message affiché dans la boîte de dialogue système.
    static func authenticate(reason: String, completion: @escaping (AuthResult) -> Void) {
        let context = LAContext()
        context.localizedFallbackTitle = "Utiliser le code"

        var error: NSError?
        // On accepte biométrie OU code d'accès de l'appareil.
        let policy: LAPolicy = .deviceOwnerAuthentication

        guard context.canEvaluatePolicy(policy, error: &error) else {
            let message = error?.localizedDescription ?? "Authentification indisponible sur cet appareil."
            DispatchQueue.main.async { completion(.failed(message)) }
            return
        }

        context.evaluatePolicy(policy, localizedReason: reason) { success, evalError in
            DispatchQueue.main.async {
                if success {
                    completion(.success)
                } else {
                    let message = evalError?.localizedDescription ?? "Authentification refusée."
                    completion(.failed(message))
                }
            }
        }
    }
}
