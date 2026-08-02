import SwiftUI

/// Esegue un'azione quando un valore **smette** di cambiare.
///
/// I campi di testo degli editor sono legati direttamente al modello, e ogni
/// lettera digitata faceva scattare un salvataggio: scrittura su disco, avviso
/// a tutte le viste che leggono quel profilo, e per le schede anche un
/// documento intero mandato su Firestore. Sei lettere, sei giri completi — con
/// il risultato che scrivere una parola richiedeva quindici secondi.
///
/// `.task(id:)` fa da sé la parte difficile: quando il valore cambia il compito
/// precedente viene annullato, quindi l'attesa riparte a ogni tasto e il
/// salvataggio arriva una volta sola, quando le dita si fermano.
struct SettleModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let delay: Duration
    let action: () -> Void

    /// Il primo giro è l'apparizione della vista, non una modifica: salvare lì
    /// vorrebbe dire scrivere ogni volta che si apre un editor senza toccare
    /// niente.
    @State private var seenFirstValue = false

    func body(content: Content) -> some View {
        content.task(id: value) {
            guard seenFirstValue else {
                seenFirstValue = true
                return
            }
            do { try await Task.sleep(for: delay) } catch { return }
            action()
        }
    }
}

extension View {
    func onSettled<Value: Equatable>(_ value: Value,
                                     after delay: Duration = .milliseconds(700),
                                     perform action: @escaping () -> Void) -> some View {
        modifier(SettleModifier(value: value, delay: delay, action: action))
    }
}
