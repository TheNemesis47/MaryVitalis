import Foundation
import Combine

/// Database esercizi caricato dal JSON in bundle.
final class ExerciseLibrary: ObservableObject {
    static let shared = ExerciseLibrary()

    @Published private(set) var all: [Exercise] = []
    @Published private(set) var isLoading = true

    private var byName: [String: Exercise] = [:]

    private(set) var bodyParts: [String] = []
    private(set) var targets: [String] = []
    private(set) var equipment: [String] = []

    private init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            assertionFailure("exercises.json mancante dal bundle")
            isLoading = false
            return
        }

        // Il file è ~2.8 MB: parsing fuori dal main thread per non bloccare il primo frame.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let decoded: [Exercise]
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                decoded = try JSONDecoder().decode([Exercise].self, from: data)
            } catch {
                assertionFailure("exercises.json non leggibile: \(error)")
                DispatchQueue.main.async { self?.isLoading = false }
                return
            }

            var index: [String: Exercise] = [:]
            for ex in decoded where index[ex.name.lowercased()] == nil {
                index[ex.name.lowercased()] = ex
            }
            let bodyParts = Self.uniqueSorted(decoded.map(\.bodyPart))
            let targets = Self.uniqueSorted(decoded.map(\.target))
            let equipment = Self.uniqueSorted(decoded.map(\.equipment))

            DispatchQueue.main.async {
                guard let self else { return }
                self.all = decoded
                self.byName = index
                self.bodyParts = bodyParts
                self.targets = targets
                self.equipment = equipment
                self.isLoading = false
            }
        }
    }

    private static func uniqueSorted(_ values: [String?]) -> [String] {
        Array(Set(values.compactMap { $0 }.filter { !$0.isEmpty })).sorted()
    }

    /// Stessa logica di `findExercise` nella SPA: match esatto sul nome, poi "contiene".
    func find(_ query: String) -> Exercise? {
        let q = query.lowercased()
        if let exact = byName[q] { return exact }
        return all.first { $0.name.lowercased().contains(q) }
    }

    func targets(for bodyPart: String?) -> [String] {
        guard let bodyPart, !bodyPart.isEmpty else { return targets }
        return Self.uniqueSorted(all.filter { $0.bodyPart == bodyPart }.map(\.target))
    }

    func filter(search: String, bodyPart: String?, target: String?, equipment: String?) -> [Exercise] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all.filter { ex in
            if let bodyPart, !bodyPart.isEmpty, ex.bodyPart != bodyPart { return false }
            if let target, !target.isEmpty, ex.target != target { return false }
            if let equipment, !equipment.isEmpty, ex.equipment != equipment { return false }
            if !q.isEmpty {
                let haystack = "\(ex.name) \(ex.equipment ?? "") \(ex.target ?? "")".lowercased()
                if !haystack.contains(q) { return false }
            }
            return true
        }
    }

    static let bodyPartIcons: [String: String] = [
        "upper arms": "💪", "upper legs": "🦵", "back": "🔙", "waist": "🔥",
        "chest": "🫀", "shoulders": "🎽", "lower legs": "🦿", "lower arms": "🤜",
        "cardio": "❤️‍🔥", "neck": "🧣"
    ]
}
