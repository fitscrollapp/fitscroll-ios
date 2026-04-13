import AVFoundation

/// Plays short feedback sounds using AVAudioPlayer so we can control volume
/// and play the bundled coin.wav at full media volume (vs. silent ringer sounds).
final class SoundManager {
    static let shared = SoundManager()

    private var coinPlayer: AVAudioPlayer?

    // AVAudioEngine + player node used for the programmatically generated
    // "ti ti tiiii" victory fanfare on the session summary screen.
    private let fanfareEngine = AVAudioEngine()
    private let fanfarePlayer = AVAudioPlayerNode()
    private var fanfareBuffer: AVAudioPCMBuffer?

    private init() {
        configureAudioSession()
        preloadCoin()
        prepareFanfare()
    }

    /// Configures playback so our short sound effects mix with other audio
    /// and still play even when the phone is on silent.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func preloadCoin() {
        guard let url = Bundle.main.url(forResource: "coin", withExtension: "wav") else {
            Logger.log("coin.wav not found in bundle", level: .warning)
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1.0
            player.prepareToPlay()
            coinPlayer = player
        } catch {
            Logger.log("Failed to create AVAudioPlayer: \(error)", level: .error)
        }
    }

    /// Plays a cheerful "coin collected" sound when a rep is counted.
    static func repEarned() {
        shared.playCoin()
    }

    /// Plays a rising three-note fanfare ("ti ti tiiii") to celebrate a
    /// completed workout session.
    static func sessionVictory() {
        shared.playFanfare()
    }

    private func playCoin() {
        guard let player = coinPlayer else { return }
        player.currentTime = 0
        player.play()
    }

    // MARK: - Fanfare

    private func prepareFanfare() {
        let sampleRate: Double = 44100
        // C5, E5, G5 — major triad, rising. Last note is held longer so the
        // cadence reads as "ti ti tiiii".
        let notes: [(freq: Double, duration: Double)] = [
            (523.25, 0.14),
            (659.25, 0.14),
            (783.99, 0.50),
        ]
        // Small silent gaps between notes so the beats are distinct.
        let gap = 0.04

        let totalDuration = notes.reduce(0.0) { $0 + $1.duration + gap }
        let totalFrames = AVAudioFrameCount(sampleRate * totalDuration)

        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: totalFrames
              ) else {
            return
        }
        buffer.frameLength = totalFrames

        guard let channel = buffer.floatChannelData?[0] else { return }

        var cursor = 0
        for (freq, duration) in notes {
            let frames = Int(sampleRate * duration)
            for i in 0..<frames {
                let t = Double(i) / sampleRate
                // Attack/release envelope keeps the tones from clicking.
                let attack = 0.008
                let release = 0.06
                var env: Double = 1.0
                if t < attack { env = t / attack }
                if t > duration - release {
                    env = max(0, (duration - t) / release)
                }
                // Mix the fundamental with a softer 2x harmonic for a
                // warmer, slightly bell-like timbre.
                let fundamental = sin(2.0 * .pi * freq * t)
                let harmonic = sin(2.0 * .pi * freq * 2.0 * t) * 0.25
                let sample = (fundamental + harmonic) * env * 0.45
                channel[cursor + i] = Float(sample)
            }
            cursor += frames

            // Silence gap between notes.
            let gapFrames = Int(sampleRate * gap)
            for i in 0..<gapFrames {
                channel[cursor + i] = 0
            }
            cursor += gapFrames
        }

        fanfareEngine.attach(fanfarePlayer)
        fanfareEngine.connect(
            fanfarePlayer,
            to: fanfareEngine.mainMixerNode,
            format: format
        )
        do {
            try fanfareEngine.start()
        } catch {
            Logger.log("Failed to start fanfare engine: \(error)", level: .error)
        }

        fanfareBuffer = buffer
    }

    private func playFanfare() {
        guard let buffer = fanfareBuffer else { return }
        if !fanfareEngine.isRunning {
            try? fanfareEngine.start()
        }
        if fanfarePlayer.isPlaying {
            fanfarePlayer.stop()
        }
        fanfarePlayer.scheduleBuffer(buffer, at: nil, options: .interrupts)
        fanfarePlayer.play()
    }
}
