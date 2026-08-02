import Foundation
import UserNotifications

/// La sveglia del recupero.
///
/// Il suono di `Feedback` esiste solo finché l'app è davanti: il cronometro
/// gira su un `Timer`, e un `Timer` sospeso non fa niente. Fra una serie e
/// l'altra il telefono finisce in tasca o si blocca da solo, ed è proprio lì
/// che l'avviso serve — quindi la fine del recupero la annuncia una notifica
/// locale, che il sistema fa scattare anche con l'app chiusa.
enum RestAlarm {
    private static let identifier = "mv.rest.finished"

    /// Chiesto all'inizio dell'allenamento, non all'avvio dell'app: così il
    /// permesso arriva quando è chiaro a cosa serve.
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// Programma l'avviso per la fine del recupero, sostituendo il precedente:
    /// +15s, −15s e pausa riscrivono sempre l'unica sveglia in ballo.
    static func schedule(endsAt: Date, label: String) {
        cancel()

        let seconds = endsAt.timeIntervalSinceNow
        guard seconds > 0.5 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Recupero finito"
        content.body = "\(label): riprendi con la serie successiva."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Vale sia per il recupero saltato sia per quello finito con l'app
    /// aperta: in quel caso il suono l'ha già fatto `Feedback`, e la notifica
    /// resterebbe solo come avviso da scartare a mano.
    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
