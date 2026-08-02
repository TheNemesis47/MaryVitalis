import Foundation

/// Il codice che un cliente detta al proprio trainer.
///
/// Va letto ad alta voce e ribattuto a mano, quindi l'alfabeto esclude i
/// caratteri che si confondono fra loro: niente `0` e `O`, niente `1`, `I`, `L`.
/// Restano 31 simboli: con 6 caratteri fanno circa 900 milioni di combinazioni,
/// più che sufficienti visto che il codice non è nemmeno una credenziale — chi
/// lo conosce può solo *chiedere* il collegamento, che il cliente deve accettare.
enum InviteCode {
    static let length = 6

    private static let alphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")

    /// I codici che l'app si tiene per sé: sono già assegnati a qualcosa, e
    /// generarli per una sede vera la renderebbe irraggiungibile.
    static let reserved: Set<String> = ["BRRERA"]

    static func generate() -> String {
        var code: String
        repeat {
            code = String((0..<length).map { _ in alphabet.randomElement() ?? "A" })
        } while reserved.contains(code)
        return code
    }

    /// Accetta quello che l'utente ha digitato comunque l'abbia scritto:
    /// minuscole, spazi, trattini. I caratteri ambigui non vengono indovinati —
    /// non sono mai generati, quindi trovarli significa che c'è un errore di
    /// battitura, ed è meglio un codice che non corrisponde di un codice che
    /// corrisponde alla persona sbagliata.
    static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { alphabet.contains($0) })
    }

    static func isValid(_ code: String) -> Bool {
        code.count == length && code.allSatisfy { alphabet.contains($0) }
    }

    /// "K7M2QX" → "K7M-2QX", più facile da dettare.
    static func formatted(_ code: String) -> String {
        guard code.count == length else { return code }
        let middle = code.index(code.startIndex, offsetBy: length / 2)
        return "\(code[code.startIndex..<middle])-\(code[middle...])"
    }
}
