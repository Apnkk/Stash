import Foundation
import UserNotifications

/// Service gérant les rappels locaux (notifications) d'expiration des cartes bancaires.
/// Fonctionne 100 % hors ligne sur l'appareil via `UserNotifications`.
enum ExpiryReminderService {

    /// Clé UserDefaults pour activer/désactiver les rappels.
    static let settingsKey = "expiry_reminders_enabled"

    /// Vérifie si l'autorisation des notifications a été accordée par l'utilisateur.
    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    /// Demande l'autorisation d'afficher des notifications locales.
    static func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            return granted
        } catch {
            return false
        }
    }

    /// Annule tous les rappels programmés pour une carte donnée.
    static func cancelReminders(for cardID: UUID) {
        let ids = [
            "stash-expiry-\(cardID.uuidString)-m1",
            "stash-expiry-\(cardID.uuidString)-m0"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Annule tous les rappels d'expiration de l'application.
    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Reprogramme les rappels d'expiration pour l'ensemble des cartes fournies.
    static func rescheduleAll(for cards: [Card]) async {
        guard UserDefaults.standard.bool(forKey: settingsKey) else {
            cancelAll()
            return
        }

        guard await isAuthorized() else { return }

        // Nettoie d'abord les anciennes requêtes
        cancelAll()

        for card in cards where card.kind == .bank && !card.expiry.isEmpty {
            scheduleReminders(for: card)
        }
    }

    /// Programme les rappels pour une carte bancaire (si la date est valide et dans le futur).
    static func scheduleReminders(for card: Card) {
        guard UserDefaults.standard.bool(forKey: settingsKey) else { return }
        guard card.kind == .bank, !card.expiry.isEmpty else { return }

        let parts = card.expiry.split(separator: "/")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let yearShort = Int(parts[1]),
              (1...12).contains(month) else {
            return
        }

        let fullYear = 2000 + yearShort
        let calendar = Calendar.current
        let now = Date()

        // 1. Rappel au début du mois d'expiration (le 1er du mois à 09:00)
        var m0Components = DateComponents()
        m0Components.year = fullYear
        m0Components.month = month
        m0Components.day = 1
        m0Components.hour = 9
        m0Components.minute = 0

        if let m0Date = calendar.date(from: m0Components), m0Date > now {
            let content = UNMutableNotificationContent()
            content.title = "Carte expirant ce mois-ci"
            content.body = "Ta carte « \(card.name) » expire à la fin du mois. Pense à vérifier la réception de ta nouvelle carte."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: m0Components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "stash-expiry-\(card.id.uuidString)-m0",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }

        // 2. Rappel 1 mois avant (le 1er du mois précédent à 09:00)
        var prevMonth = month - 1
        var prevYear = fullYear
        if prevMonth < 1 {
            prevMonth = 12
            prevYear -= 1
        }

        var m1Components = DateComponents()
        m1Components.year = prevYear
        m1Components.month = prevMonth
        m1Components.day = 1
        m1Components.hour = 9
        m1Components.minute = 0

        if let m1Date = calendar.date(from: m1Components), m1Date > now {
            let content = UNMutableNotificationContent()
            content.title = "Carte expirant bientôt"
            content.body = "Ta carte « \(card.name) » expire le mois prochain (\(card.expiry))."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: m1Components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "stash-expiry-\(card.id.uuidString)-m1",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }
}
