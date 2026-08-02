import SwiftUI

struct ExercisesView: View {
    enum Preset: Equatable {
        case bodyPart(String)
        case target(String)
    }

    @EnvironmentObject private var library: ExerciseLibrary
    @Binding var preset: Preset?

    @State private var search = ""
    @State private var bodyPart = ""
    @State private var target = ""
    @State private var equipment = ""
    @State private var page = 1
    @State private var detail: ExerciseDetail?

    private let pageSize = 24

    private var filtered: [Exercise] {
        library.filter(search: search, bodyPart: bodyPart, target: target, equipment: equipment)
    }

    private var totalPages: Int { max(1, Int(ceil(Double(filtered.count) / Double(pageSize)))) }

    private var displayed: [Exercise] {
        let start = (page - 1) * pageSize
        guard start < filtered.count else { return [] }
        return Array(filtered[start..<min(start + pageSize, filtered.count)])
    }

    private var hasFilters: Bool {
        !search.isEmpty || !bodyPart.isEmpty || !target.isEmpty || !equipment.isEmpty
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(eyebrow: "Database", title: "Tutti gli esercizi",
                               subtitle: "Filtra per distretto, muscolo o attrezzo. Tocca una card per aprire le istruzioni complete.")
                        .id("top")

                    filters

                    if library.isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else if displayed.isEmpty {
                        VStack(spacing: 12) {
                            EmptyStateView(icon: "🔍", title: "Nessun esercizio trovato",
                                           message: "Prova con un altro termine o rimuovi qualche filtro.")
                            if hasFilters {
                                Button("Azzera i filtri", action: resetAll)
                                    .buttonStyle(GhostButtonStyle())
                            }
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 12)], spacing: 12) {
                            ForEach(displayed) { ex in
                                ExerciseCard(exercise: ex) { detail = ExerciseDetail(exercise: ex, note: nil) }
                            }
                        }
                        Pagination(page: page, totalPages: totalPages) { newPage in
                            page = newPage
                            withAnimation { proxy.scrollTo("top", anchor: .top) }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
        }
        .pageBackground()
        .navigationTitle("Esercizi")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detail) { ExerciseDetailView(detail: $0) }
        .onChange(of: search) { _, _ in page = 1 }
        .onChange(of: bodyPart) { _, _ in page = 1; target = "" }
        .onChange(of: target) { _, _ in page = 1 }
        .onChange(of: equipment) { _, _ in page = 1 }
        .onAppear(perform: applyPreset)
        .onChange(of: preset) { _, _ in applyPreset() }
    }

    private func applyPreset() {
        guard let preset else { return }
        switch preset {
        case .bodyPart(let value):
            bodyPart = value
            target = ""
        case .target(let value):
            bodyPart = ""
            target = value
        }
        search = ""
        equipment = ""
        page = 1
        self.preset = nil
    }

    private func resetAll() {
        search = ""; bodyPart = ""; target = ""; equipment = ""; page = 1
    }

    private var filters: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textFaint)
                TextField("Cerca per nome, muscolo o attrezzo…", text: $search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.text)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textFaint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))

            HStack(spacing: 8) {
                FilterMenu(title: "Distretto", all: "Tutti i distretti",
                           options: library.bodyParts, selection: $bodyPart)
                FilterMenu(title: "Muscolo", all: "Tutti i muscoli",
                           options: library.targets(for: bodyPart), selection: $target)
                FilterMenu(title: "Attrezzo", all: "Tutti gli attrezzi",
                           options: library.equipment, selection: $equipment)
            }

            HStack {
                Text("**\(filtered.count)** risultati")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textDim)
                Spacer()
                if hasFilters {
                    Button("Azzera", action: resetAll)
                        .font(.system(size: 13, weight: .semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.defaultAccent)
                }
            }
        }
    }
}

struct FilterMenu: View {
    let title: String
    let all: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        Menu {
            Button(all) { selection = "" }
            ForEach(options, id: \.self) { option in
                Button(Fmt.capitalizedFirst(option)) { selection = option }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.isEmpty ? title : Fmt.capitalizedFirst(selection))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(selection.isEmpty ? Theme.textDim : Color(hex: "#0a0f1a"))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(selection.isEmpty ? Theme.surface : Theme.defaultAccent, in: Capsule())
            .overlay(Capsule().stroke(selection.isEmpty ? Theme.border : .clear, lineWidth: 1))
        }
    }
}

struct Pagination: View {
    let page: Int
    let totalPages: Int
    let setPage: (Int) -> Void

    private var items: [Int] {
        guard totalPages > 1 else { return [] }
        var wanted: Set<Int> = [1, totalPages]
        for p in (page - 1)...(page + 1) where p > 1 && p < totalPages { wanted.insert(p) }
        return wanted.sorted()
    }

    var body: some View {
        if totalPages > 1 {
            HStack(spacing: 6) {
                pageButton("←", enabled: page > 1) { setPage(page - 1) }
                ForEach(Array(items.enumerated()), id: \.offset) { index, p in
                    if index > 0 && p - items[index - 1] > 1 {
                        Text("…").foregroundStyle(Theme.textFaint)
                    }
                    pageButton("\(p)", active: p == page) { setPage(p) }
                }
                pageButton("→", enabled: page < totalPages) { setPage(page + 1) }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }

    private func pageButton(_ label: String, active: Bool = false, enabled: Bool = true,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(active ? Color(hex: "#0a0f1a") : (enabled ? Theme.textDim : Theme.textFaint.opacity(0.4)))
                .frame(minWidth: 34, minHeight: 34)
                .background(active ? Theme.defaultAccent : Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? .clear : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
