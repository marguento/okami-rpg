import AVFoundation

// MARK: — SFX enum

enum SFX {
    case step, sword, swordCrit, miss, playerHit, kill, death
    case door, stairs, secret, pickup, goldDrop, equip, relic
    case projLaunch, projHit, trap, bossPhase, altar, victory
    case skillStrike, skillFortify, skillWarcry
    case spellFire, spellIce, spellLightning, spellPoison, spellShadow, spellAmbush
}

// MARK: — AudioEngine

final class AudioEngine {
    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private var muted: Bool { AppSettings.sfxMuted }
    private var musicOff: Bool { AppSettings.musicMuted }

    // Music oscillator state (accessed only from audio thread)
    private var dronePhase: Double = 0
    private var drone2Phase: Double = 0
    private var droneFreq: Double = 130.81
    private var droneSource: AVAudioSourceNode?
    private var melodyTimer: Timer?

    private let sr: Double = 44100

    private var engineAvailable = false

    private init() {
        #if !targetEnvironment(simulator)
        configureSession()
        startEngine()
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
        #endif
    }

    private func configureSession() {
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw),
              type == .ended else { return }
        startEngine()
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        do { try engine.start(); engineAvailable = true } catch { engineAvailable = false }
    }

    // MARK: — SFX

    func play(_ sfx: SFX) {
        guard !muted else { return }
        let buffer = makeSFX(sfx)
        scheduleBuffer(buffer)
    }

    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer) {
        guard engineAvailable else { return }
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: buffer.format)
        node.scheduleBuffer(buffer) { [weak self] in
            DispatchQueue.main.async { self?.engine.detach(node) }
        }
        node.play()
    }

    // MARK: — Music

    func startMusic(floor: Int) {
        stopMusic()
        guard !musicOff, engineAvailable else { return }

        let scale: [Double] = [261.63, 293.66, 329.63, 392.00, 440.00]
        let oct: Double = floor >= 9 ? 4 : floor >= 5 ? 2 : 1
        droneFreq = scale[floor % scale.count] * oct
        dronePhase = 0; drone2Phase = 0

        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        let src = AVAudioSourceNode { [weak self] _, _, frameCount, abl in
            guard let s = self else { return noErr }
            let ptr = UnsafeMutableAudioBufferListPointer(abl)
            for i in 0..<Int(frameCount) {
                let v = Float(sin(s.dronePhase) * 0.016 + sin(s.drone2Phase) * 0.008)
                s.dronePhase  += 2 * .pi * s.droneFreq / s.sr
                s.drone2Phase += 2 * .pi * (s.droneFreq * 1.498) / s.sr
                if s.dronePhase  > 2 * .pi { s.dronePhase  -= 2 * .pi }
                if s.drone2Phase > 2 * .pi { s.drone2Phase -= 2 * .pi }
                for buf in ptr {
                    buf.mData!.assumingMemoryBound(to: Float.self)[i] = v
                }
            }
            return noErr
        }
        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: fmt)
        droneSource = src
        scheduleMelody(scale: scale, oct: oct)
    }

    func stopMusic() {
        melodyTimer?.invalidate(); melodyTimer = nil
        if let src = droneSource { engine.detach(src); droneSource = nil }
    }

    private func scheduleMelody(scale: [Double], oct: Double) {
        let delay = 1.0 + Double.random(in: 0...2.5)
        melodyTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let s = self, !s.musicOff else { return }
            let buf = s.tone(Float(scale.randomElement()! * oct), dur: 0.42, wave: .sine, vol: 0.038)
            s.scheduleBuffer(buf)
            s.scheduleMelody(scale: scale, oct: oct)
        }
    }

    // MARK: — Wave synthesis

    private enum Wave { case sine, square, saw }

    private func tone(_ freq: Float, dur: Float, wave: Wave, vol: Float) -> AVAudioPCMBuffer {
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        let n = Int(sr * Double(dur))
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(n))!
        buf.frameLength = AVAudioFrameCount(n)
        let d = buf.floatChannelData![0]
        var phase: Float = 0
        let dph = 2 * Float.pi * freq / Float(sr)
        for i in 0..<n {
            let t = Float(i) / Float(sr)
            let env = min(t / 0.005, 1.0) * max(0, 1.0 - t / dur * 1.3)
            var s: Float
            switch wave {
            case .sine:   s = sin(phase)
            case .square: s = phase.truncatingRemainder(dividingBy: 2 * .pi) < .pi ? 1.0 : -1.0
            case .saw:    s = 2 * (phase / (2 * .pi) - floor(phase / (2 * .pi) + 0.5))
            }
            d[i] = s * env * vol
            phase += dph
            if phase > 2 * .pi { phase -= 2 * .pi }
        }
        return buf
    }

    private func slide(_ f0: Float, _ f1: Float, dur: Float, vol: Float, wave: Wave = .sine) -> AVAudioPCMBuffer {
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        let n = Int(sr * Double(dur))
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(n))!
        buf.frameLength = AVAudioFrameCount(n)
        let d = buf.floatChannelData![0]
        var phase: Float = 0
        for i in 0..<n {
            let t = Float(i) / Float(sr)
            let freq = f0 + (f1 - f0) * (t / dur)
            let env = min(t / 0.004, 1.0) * max(0, 1.0 - t / dur * 1.2)
            var s: Float
            switch wave {
            case .sine:   s = sin(phase)
            case .square: s = phase.truncatingRemainder(dividingBy: 2 * .pi) < .pi ? 1.0 : -1.0
            case .saw:    s = 2 * (phase / (2 * .pi) - floor(phase / (2 * .pi) + 0.5))
            }
            d[i] = s * env * vol
            phase += 2 * .pi * freq / Float(sr)
            if phase > 2 * .pi { phase -= 2 * .pi }
        }
        return buf
    }

    private func chord(_ freqs: [Float], dur: Float, wave: Wave, vol: Float) -> AVAudioPCMBuffer {
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        let n = Int(sr * Double(dur))
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(n))!
        buf.frameLength = AVAudioFrameCount(n)
        let d = buf.floatChannelData![0]
        let perVol = vol / Float(freqs.count)
        var phases = [Float](repeating: 0, count: freqs.count)
        for i in 0..<n {
            let t = Float(i) / Float(sr)
            let env = min(t / 0.01, 1.0) * max(0, 1.0 - t / dur * 1.15)
            var s: Float = 0
            for (fi, freq) in freqs.enumerated() {
                switch wave {
                case .sine:   s += sin(phases[fi])
                case .square: s += phases[fi].truncatingRemainder(dividingBy: 2 * .pi) < .pi ? 1.0 : -1.0
                case .saw:    s += 2 * (phases[fi] / (2 * .pi) - floor(phases[fi] / (2 * .pi) + 0.5))
                }
                phases[fi] += 2 * .pi * freq / Float(sr)
                if phases[fi] > 2 * .pi { phases[fi] -= 2 * .pi }
            }
            d[i] = s * env * perVol
        }
        return buf
    }

    // MARK: — SFX definitions

    private func makeSFX(_ sfx: SFX) -> AVAudioPCMBuffer {
        switch sfx {
        case .step:           return tone(160,  dur: 0.05, wave: .square, vol: 0.09)
        case .sword:          return slide(440, 330,  dur: 0.10, vol: 0.30, wave: .saw)
        case .swordCrit:      return slide(880, 1320, dur: 0.18, vol: 0.40)
        case .miss:           return tone(180,  dur: 0.12, wave: .sine,   vol: 0.15)
        case .playerHit:      return slide(220, 90,   dur: 0.15, vol: 0.50, wave: .saw)
        case .kill:           return slide(660, 220,  dur: 0.22, vol: 0.38)
        case .death:          return slide(330, 55,   dur: 0.80, vol: 0.50)
        case .door:           return tone(280,  dur: 0.08, wave: .square, vol: 0.22)
        case .stairs:         return slide(330, 660,  dur: 0.28, vol: 0.35)
        case .secret:         return chord([523.25, 659.25, 783.99], dur: 0.45, wave: .sine, vol: 0.35)
        case .pickup:         return slide(392, 523,  dur: 0.12, vol: 0.28)
        case .goldDrop:       return chord([523.25, 659.25], dur: 0.14, wave: .sine, vol: 0.28)
        case .equip:          return tone(392,  dur: 0.14, wave: .square, vol: 0.22)
        case .relic:          return chord([523.25, 659.25, 783.99, 1046.5], dur: 0.55, wave: .sine, vol: 0.32)
        case .projLaunch:     return tone(800,  dur: 0.06, wave: .saw,    vol: 0.20)
        case .projHit:        return tone(200,  dur: 0.09, wave: .saw,    vol: 0.32)
        case .trap:           return slide(600, 150,  dur: 0.22, vol: 0.42)
        case .bossPhase:      return chord([110, 138.59, 164.81], dur: 0.50, wave: .saw, vol: 0.45)
        case .altar:          return chord([220, 277.18, 329.63], dur: 0.42, wave: .sine, vol: 0.30)
        case .victory:        return chord([523.25, 659.25, 783.99, 1046.5], dur: 0.90, wave: .sine, vol: 0.40)
        case .skillStrike:    return slide(880, 440,  dur: 0.14, vol: 0.38, wave: .saw)
        case .skillFortify:   return chord([329.63, 415.30, 523.25], dur: 0.32, wave: .square, vol: 0.25)
        case .skillWarcry:    return chord([220, 277.18, 329.63], dur: 0.38, wave: .saw, vol: 0.48)
        case .spellFire:      return slide(440, 880,  dur: 0.18, vol: 0.38)
        case .spellIce:       return tone(1200, dur: 0.14, wave: .sine,   vol: 0.24)
        case .spellLightning: return chord([880, 1760], dur: 0.10, wave: .square, vol: 0.38)
        case .spellPoison:    return slide(330, 165,  dur: 0.24, vol: 0.28)
        case .spellShadow:    return tone(165,  dur: 0.22, wave: .sine,   vol: 0.20)
        case .spellAmbush:    return slide(660, 1320, dur: 0.14, vol: 0.40, wave: .saw)
        }
    }
}
