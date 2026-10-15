import AVFoundation

/// Centralized sound effects. Buffers are synthesized once on first use and
/// replayed through shared `AVAudioPlayerNode`s so each call is allocation-
/// free and stays tight to the haptic that fires alongside it. The engine
/// runs only around a sound: `warm()` starts it when a log is coming (the
/// knob's touch-down) and it stops a few seconds after the last one, so no
/// audio thread runs while the app sits open.
enum SoundEffects {
    private static let engine = AVAudioEngine()
    private static let player = AVAudioPlayerNode()
    /// The perfect-day bloom gets its own node so it rings over the log
    /// chime that triggered it instead of cutting it off.
    private static let bloomPlayer = AVAudioPlayerNode()
    private static let sampleRate: Double = 44_100
    private static var configured = false
    private static var format: AVAudioFormat?
    private static var chimeBuffers: [Int: AVAudioPCMBuffer] = [:]
    private static var bloomBuffer: AVAudioPCMBuffer?
    /// Semitones above the base bell, one per step of the day: a major
    /// pentatonic climb that tops out at the fifth.
    private static let dayScale = [0, 2, 4, 7]

    private static var idleStop: Task<Void, Never>?

    /// Starts the engine ahead of a sound, off the moment it is needed.
    /// Safe to call repeatedly; it winds down on its own if nothing plays.
    static func warm() {
        guard AppPreferences.isLogSoundOn else { return }
        configure()
        startEngine()
        stopWhenIdle(after: 4)
    }

    /// Bright two-note bell that fires when a habit is logged. `progress` is
    /// the share of today done after this log, and the bell climbs with it,
    /// so the last log of the day rings highest. Silent when Settings → Log
    /// sound is off.
    static func logChime(progress: Double = 0) {
        guard AppPreferences.isLogSoundOn else { return }
        configure()
        let index = Int((min(max(progress, 0), 1) * Double(dayScale.count - 1)).rounded())
        guard let buffer = chime(semitones: dayScale[index]) else { return }
        play(buffer, on: player)
    }

    /// A rolled major chord under the last log's bell, for a perfect day.
    static func perfectDay() {
        guard AppPreferences.isLogSoundOn else { return }
        configure()
        if bloomBuffer == nil, let format {
            bloomBuffer = renderBloom(format: format)
        }
        guard let bloomBuffer else { return }
        play(bloomBuffer, on: bloomPlayer)
    }

    private static func play(_ buffer: AVAudioPCMBuffer, on node: AVAudioPlayerNode) {
        startEngine()
        guard engine.isRunning else { return }
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        node.play()
        stopWhenIdle(after: Double(buffer.frameLength) / sampleRate + 1)
    }

    private static func startEngine() {
        guard !engine.isRunning else { return }
        try? engine.start()
    }

    /// Stops the engine once nothing has played for `seconds`; each sound
    /// or warm-up pushes it back.
    private static func stopWhenIdle(after seconds: Double) {
        idleStop?.cancel()
        idleStop = Task {
            guard (try? await Task.sleep(for: .seconds(seconds))) != nil else { return }
            engine.stop()
        }
    }

    private static func chime(semitones: Int) -> AVAudioPCMBuffer? {
        if let cached = chimeBuffers[semitones] { return cached }
        guard let format else { return nil }
        let buffer = renderLogChime(format: format, semitones: semitones)
        chimeBuffers[semitones] = buffer
        return buffer
    }

    // MARK: - Setup

    private static func configure() {
        guard !configured else { return }
        configured = true

        // Playback (not ambient) so the chime still fires when the ringer
        // switch is off. A habit log is a deliberate user action and should
        // be heard. mixWithOthers keeps any music or podcast playing through.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        // Activation can block for a while, so it runs once, off the main
        // thread. Nothing deactivates it, and a start that beats it lands
        // fine: the engine activates the session itself when it has to.
        Task.detached { try? AVAudioSession.sharedInstance().setActive(true) }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }
        self.format = format
        for node in [player, bloomPlayer] {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
        chimeBuffers[0] = renderLogChime(format: format, semitones: 0)
    }

    // MARK: - Synthesis

    /// Renders a short two-note bell: an E6 mallet attack with a B6 overtone
    /// joining ~80 ms later, both decaying exponentially, transposed up by
    /// `semitones`. Adds a faint sub-octave for body. Total length ~0.55 s.
    private static func renderLogChime(format: AVAudioFormat, semitones: Int) -> AVAudioPCMBuffer? {
        let duration: Double = 0.55
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return nil }

        let transpose = pow(2, Double(semitones) / 12)
        let note1: Double = 1318.51 * transpose   // E6
        let note2: Double = 1975.53 * transpose   // B6
        let crossover: Double = 0.08
        let attack: Double = 0.005

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let attackEnv = t < attack ? t / attack : 1.0
            let env1 = attackEnv * exp(-3.0 * t)

            var sample = sin(2.0 * .pi * note1 * t) * env1 * 0.45
            sample += sin(2.0 * .pi * (note1 / 2.0) * t) * env1 * 0.12

            if t >= crossover {
                let t2 = t - crossover
                let env2 = exp(-3.5 * t2)
                sample += sin(2.0 * .pi * note2 * t2) * env2 * 0.4
            }

            channel[frame] = Float(sample * 0.7)
        }
        return buffer
    }

    /// Renders an E major chord (E5, G#5, B5, E6) rolled upward 60 ms apart
    /// after a short rest, so it blooms just under the log chime's bell. Soft
    /// attacks and a slow decay keep it warm rather than bright. ~1.6 s.
    private static func renderBloom(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let duration: Double = 1.6
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return nil }

        let notes: [Double] = [659.26, 830.61, 987.77, 1318.51]
        let lead: Double = 0.12
        let roll: Double = 0.06
        let attack: Double = 0.012

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            var sample = 0.0
            for (i, note) in notes.enumerated() {
                let tn = t - lead - Double(i) * roll
                guard tn > 0 else { continue }
                let env = (tn < attack ? tn / attack : 1.0) * exp(-2.4 * tn)
                sample += sin(2.0 * .pi * note * tn) * env * 0.2
                sample += sin(2.0 * .pi * note * 2 * tn) * env * 0.04
            }
            // Quieter than the bell: it plays over one, and should not clip.
            channel[frame] = Float(sample * 0.55)
        }
        return buffer
    }
}
