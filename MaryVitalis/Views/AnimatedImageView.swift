import SwiftUI
import ImageIO
import UIKit

/// Le anteprime del dataset sono GIF: `AsyncImage` mostrerebbe solo il primo
/// fotogramma, quindi le decodifichiamo con ImageIO e le animiamo in una UIImageView.
struct AnimatedImageView: View {
    let url: URL

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                AnimatedImageRepresentable(image: image)
            } else if failed {
                ZStack {
                    Theme.surfaceHi
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundStyle(Theme.textFaint)
                }
                .accessibilityLabel("Immagine non disponibile")
            } else {
                ZStack {
                    Theme.surfaceHi
                    ProgressView()
                }
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        image = nil
        failed = false

        for attempt in 0..<2 {
            do {
                let data = try await RemoteMediaCache.shared.data(for: url)
                try Task.checkCancellation()
                // Decodificare una GIF vuol dire ricostruirne tutti i
                // fotogrammi, e `.task` di una vista gira sul main actor: con
                // ventiquattro card in griglia l'interfaccia restava ferma per
                // secondi, di solito appena tornati nell'app. Il lavoro va
                // fuori dal thread che disegna.
                let decoded = await Task.detached(priority: .userInitiated) {
                    DecodedImage(image: UIImage.animated(data: data))
                }.value.image
                try Task.checkCancellation()

                guard let decoded else {
                    await RemoteMediaCache.shared.remove(url)
                    failed = true
                    return
                }
                image = decoded
                return
            } catch is CancellationError {
                // Le celle della griglia vengono riusate durante lo scroll: una
                // cancellazione non significa che il telefono sia offline.
                return
            } catch {
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                } else {
                    failed = true
                }
            }
        }
    }
}

/// Fa attraversare al risultato il confine fra i due task: `UIImage` non è
/// `Sendable`, ma questa è appena stata creata e non la sta guardando nessuno.
private struct DecodedImage: @unchecked Sendable {
    let image: UIImage?
}

private actor RemoteMediaCache {
    static let shared = RemoteMediaCache()

    private var dataByURL: [URL: Data] = [:]
    private var insertionOrder: [URL] = []
    private let maximumItems = 64

    func data(for url: URL) async throws -> Data {
        if let cached = dataByURL[url] { return cached }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard !data.isEmpty else { throw URLError(.zeroByteResource) }

        dataByURL[url] = data
        insertionOrder.removeAll { $0 == url }
        insertionOrder.append(url)
        if insertionOrder.count > maximumItems {
            let removed = insertionOrder.removeFirst()
            dataByURL[removed] = nil
        }
        return data
    }

    func remove(_ url: URL) {
        dataByURL[url] = nil
        insertionOrder.removeAll { $0 == url }
    }
}

private struct AnimatedImageRepresentable: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = image
    }
}

extension UIImage {
    /// Costruisce una `UIImage` animata da dati GIF (o una statica per gli altri formati).
    static func animated(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return UIImage(data: data) }

        var frames: [UIImage] = []
        var duration: Double = 0

        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            duration += frameDelay(source: source, index: index)
        }

        guard !frames.isEmpty else { return UIImage(data: data) }
        return UIImage.animatedImage(with: frames, duration: duration > 0 ? duration : Double(frames.count) / 15)
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> Double {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 0.1 }

        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double
        let delay = unclamped ?? clamped ?? 0.1
        // Sotto i 20 ms i browser normalizzano a 100 ms: facciamo lo stesso.
        return delay < 0.02 ? 0.1 : delay
    }
}
