import AVFoundation
import UIKit

/// Suono + vibrazione: l'equivalente di `chime()` della SPA.
enum Feedback {
    private static var engine: AVAudioEngine?
    private static var player: AVAudioPlayerNode?

    static func chime(_ tones: [Double]) {
        playTones(tones)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func restFinished() { chime([880, 1170]) }
    /// Due note che scendono: si distingue a orecchio dal trillo di fine
    /// recupero senza bisogno di guardare il telefono.
    static func restStarted() { chime([784, 523]) }
    static func sessionStarted() { chime([523, 784]) }
    static func waterReminder() { chime([660]) }

    // I generatori si tengono: crearne uno nuovo a ogni tocco significa
    // riaccendere il motore aptico ogni volta, e questi metodi vengono chiamati
    // su ogni singolo tap dell'app.
    @MainActor private static let selection = UISelectionFeedbackGenerator()
    @MainActor private static let notification = UINotificationFeedbackGenerator()

    @MainActor
    static func tap() {
        selection.selectionChanged()
        selection.prepare()
    }

    @MainActor
    static func success() {
        notification.notificationOccurred(.success)
    }

    // MARK: - Sintesi delle note

    private static func playTones(_ tones: [Double]) {
        guard !tones.isEmpty else { return }

        let sampleRate = 44_100.0
        let toneDuration = 0.24
        let gap = 0.26
        let total = gap * Double(tones.count - 1) + toneDuration

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(total * sampleRate)) else { return }

        buffer.frameLength = buffer.frameCapacity
        guard let samples = buffer.floatChannelData?[0] else { return }
        for i in 0..<Int(buffer.frameLength) { samples[i] = 0 }

        for (index, freq) in tones.enumerated() {
            let start = Int(Double(index) * gap * sampleRate)
            let count = Int(toneDuration * sampleRate)
            for i in 0..<count {
                let position = start + i
                guard position < Int(buffer.frameLength) else { break }
                let t = Double(i) / sampleRate
                // Attacco rapido e coda in dissolvenza, come l'inviluppo del Web Audio.
                let envelope = min(1, t / 0.02) * exp(-t * 9)
                samples[position] += Float(sin(2 * .pi * freq * t) * envelope * 0.3)
            }
        }

        do {
            // `.playback` e non `.ambient`: in palestra il telefono sta quasi
            // sempre in silenzioso, e con `.ambient` l'avviso di fine recupero
            // non si sentirebbe mai. `.mixWithOthers` lascia suonare la musica.
            try AVAudioSession.sharedInstance().setCategory(.playback,
                                                            options: [.mixWithOthers, .duckOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: [])

            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: []) {
                DispatchQueue.main.async {
                    engine.stop()
                    if Feedback.engine === engine { Feedback.engine = nil; Feedback.player = nil }
                    // Senza disattivare, la musica di chi ascolta resterebbe
                    // abbassata fino alla chiusura dell'app.
                    try? AVAudioSession.sharedInstance()
                        .setActive(false, options: [.notifyOthersOnDeactivation])
                }
            }
            player.play()
            // Trattenute finché il buffer non ha finito.
            Feedback.engine = engine
            Feedback.player = player
        } catch {
            // Audio non disponibile: resta la vibrazione.
        }
    }
}
