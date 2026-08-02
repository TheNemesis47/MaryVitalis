import Foundation

/// Un esercizio del database (1324 voci, dataset Gym Visual).
/// Il JSON in bundle è la versione ridotta di `exercises.json` del sito:
/// tenute solo le lingue italiano/inglese.
struct Exercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let bodyPart: String?
    let target: String?
    let equipment: String?
    let muscleGroup: String?
    let secondaryMuscles: [String]
    let image: String?
    let gif: String?
    let instructionsIt: String?
    let instructionsEn: String?
    let stepsIt: [String]?
    let stepsEn: [String]?

    /// Base delle immagini/gif, la stessa usata dalla SPA.
    static let mediaBase = URL(string: "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/")!

    var imageURL: URL? { image.flatMap { URL(string: $0, relativeTo: Exercise.mediaBase) } }
    var gifURL: URL? { gif.flatMap { URL(string: $0, relativeTo: Exercise.mediaBase) } }

    /// Preferisce l'italiano, poi l'inglese: stesso criterio di `pickLang` nella SPA.
    var steps: [String] {
        if let it = stepsIt, !it.isEmpty { return it }
        if let en = stepsEn, !en.isEmpty { return en }

        let text = instructionsIt ?? instructionsEn ?? ""
        guard !text.isEmpty else { return [] }
        // Spezza sul punto, come faceva la regex `(?<=\.)\s+`
        return text
            .split(separator: ".", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0 + "." }
    }

    var instructions: String? { instructionsIt ?? instructionsEn }
}
