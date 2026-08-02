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
                    Image(systemName: "wifi.slash").foregroundStyle(Theme.textFaint)
                }
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
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let decoded = UIImage.animated(data: data) {
                image = decoded
            } else {
                failed = true
            }
        } catch {
            failed = true
        }
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
