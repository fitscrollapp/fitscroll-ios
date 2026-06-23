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

    // Separate engine for the electric zap so we can retrigger it
    // without colliding with the fanfare's scheduling.
    private let zapEngine = AVAudioEngine()
    private let zapPlayer = AVAudioPlayerNode()
    private var zapBufferMid: AVAudioPCMBuffer?
    private var zapBufferMega: AVAudioPCMBuffer?

    private init() {
        configureAudioSession()
        preloadCoin()
        prepareFanfare()
        prepareZap()
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

    /// Short electric "zap" burst — played at every 5th rep milestone.
    static func electricZap() {
        shared.playZap(mega: false)
    }

    /// Longer, heavier electric zap — played at every 10th rep.
    static func electricMegaZap() {
        shared.playZap(mega: true)
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

    // MARK: - Electric zap

    private func prepareZap() {
        let sampleRate: Double = 44100
        zapBufferMid = synthesizeZap(
            sampleRate: sampleRate,
            duration: 0.28,
            startFreq: 3200,
            endFreq: 120,
            noiseLevel: 0.35,
            gain: 0.55
        )
        zapBufferMega = synthesizeZap(
            sampleRate: sampleRate,
            duration: 0.45,
            startFreq: 4400,
            endFreq: 80,
            noiseLevel: 0.55,
            gain: 0.70
        )

        guard let first = zapBufferMid else { return }
        zapEngine.attach(zapPlayer)
        zapEngine.connect(
            zapPlayer,
            to: zapEngine.mainMixerNode,
            format: first.format
        )
        do {
            try zapEngine.start()
        } catch {
            Logger.log("Failed to start zap engine: \(error)", level: .error)
        }
    }

    /// Builds a short "electric zap" PCM buffer on the fly. The sound
    /// is a mix of:
    ///  - a descending pitched square-ish wave (`startFreq` → `endFreq`)
    ///  - a pinch of band-limited white noise for sparkle
    ///  - a sharp attack + exponential decay envelope so it reads as
    ///    a hit rather than a tone
    private func synthesizeZap(
        sampleRate: Double,
        duration: Double,
        startFreq: Double,
        endFreq: Double,
        noiseLevel: Double,
        gain: Double
    ) -> AVAudioPCMBuffer? {
        let totalFrames = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: totalFrames
              ) else {
            return nil
        }
        buffer.frameLength = totalFrames
        guard let channel = buffer.floatChannelData?[0] else { return nil }

        // Maintain oscillator phase across samples to avoid clicks as
        // the frequency sweeps.
        var phase: Double = 0

        for i in 0..<Int(totalFrames) {
            let t = Double(i) / sampleRate
            let progress = t / duration

            // Exponential frequency sweep (high → low). Sounds like a
            // discharge spark racing down in pitch.
            let freq = startFreq * pow(endFreq / startFreq, progress)
            phase += 2 * .pi * freq / sampleRate
            if phase > 2 * .pi { phase -= 2 * .pi }

            // Soft square via hard clip of a sine — harmonically richer
            // than a pure sine, cheaper than a real band-limited square.
            let sine = sin(phase)
            let square = max(-1, min(1, sine * 2.5))

            // Band-limited-ish noise: white noise passed through a
            // crude high-pass by subtracting a running average.
            let noise = Double.random(in: -1...1)

            // Exponential decay envelope with sharp attack.
            let attack = 0.006
            let attackEnv = min(1.0, t / attack)
            let decay = exp(-progress * 6.5)
            let env = attackEnv * decay

            let sample = (square * (1 - noiseLevel) + noise * noiseLevel)
                * env * gain
            channel[i] = Float(max(-1, min(1, sample)))
        }

        return buffer
    }

    private func playZap(mega: Bool) {
        let buffer = mega ? zapBufferMega : zapBufferMid
        guard let buffer = buffer else { return }
        if !zapEngine.isRunning {
            try? zapEngine.start()
        }
        if zapPlayer.isPlaying {
            zapPlayer.stop()
        }
        zapPlayer.scheduleBuffer(buffer, at: nil, options: .interrupts)
        zapPlayer.play()
    }
}
