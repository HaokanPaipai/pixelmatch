import AVFoundation
import UIKit

final class AudioManager {

    static let shared = AudioManager()
    private init() { setupEngine() }

    private var engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var musicNode = AVAudioPlayerNode()
    private var sfxMixer = AVAudioMixerNode()
    private var musicMixer = AVAudioMixerNode()
    private var isEngineRunning = false
    private var isMusicLooping = false

    // MARK: - Setup

    private func setupEngine() {
        // All buffers are synthesized as mono 44.1 kHz — the connection
        // format must match, or AVAudioEngine throws a channel-count mismatch.
        // The engine's mainMixerNode upmixes mono→stereo automatically.
        let mono = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        engine.attach(playerNode)
        engine.attach(musicNode)
        engine.attach(sfxMixer)
        engine.attach(musicMixer)

        engine.connect(playerNode, to: sfxMixer,          format: mono)
        engine.connect(sfxMixer,   to: engine.mainMixerNode, format: mono)
        engine.connect(musicNode,  to: musicMixer,         format: mono)
        engine.connect(musicMixer, to: engine.mainMixerNode, format: mono)

        musicMixer.outputVolume = 0.35
        sfxMixer.outputVolume = 1.0

        try? engine.start()
        isEngineRunning = true
    }

    // MARK: - Music

    func startMusic() {
        guard PlayerData.shared.musicEnabled, !isMusicLooping else { return }
        isMusicLooping = true
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.loopMusic()
        }
    }

    func stopMusic() {
        isMusicLooping = false
        musicNode.stop()
    }

    func setMusicEnabled(_ enabled: Bool) {
        if enabled { startMusic() } else { stopMusic() }
    }

    private func loopMusic() {
        while isMusicLooping {
            guard let buf = makeMusicBuffer() else { break }
            let sem = DispatchSemaphore(value: 0)
            musicNode.scheduleBuffer(buf) { sem.signal() }
            if !musicNode.isPlaying { musicNode.play() }
            sem.wait()
        }
    }

    private func makeMusicBuffer() -> AVAudioPCMBuffer? {
        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let bpm: Double = 120
        let beatDur = 60.0 / bpm
        let noteDur = beatDur * 0.5

        // Pixel-style chiptune melody (8-bit arpeggio pattern)
        let notes: [Double] = [
            261.6, 329.6, 392.0, 523.3,  // C4 E4 G4 C5 (C major arpeggio)
            392.0, 329.6, 523.3, 659.3,  // G4 E4 C5 E5
            293.7, 369.9, 440.0, 587.3,  // D4 F#4 A4 D5
            440.0, 369.9, 587.3, 493.9,  // A4 F#4 D5 B4
        ]

        let totalDur = noteDur * Double(notes.count)
        let frameCount = AVAudioFrameCount(sampleRate * totalDur)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?[0] else { return nil }

        for (ni, freq) in notes.enumerated() {
            let noteStart = Int(sampleRate * noteDur * Double(ni))
            let noteEnd   = Int(sampleRate * noteDur * Double(ni + 1))
            let noteLen   = noteEnd - noteStart

            for i in noteStart..<min(noteEnd, Int(frameCount)) {
                let t = Double(i - noteStart) / sampleRate
                let progress = Double(i - noteStart) / Double(noteLen)

                // Short attack, short release
                let env: Double
                let atk = 0.02
                let rel = 0.08
                if t < atk { env = t / atk }
                else if progress > 1.0 - rel { env = (1.0 - progress) / rel }
                else { env = 0.85 }

                // Square wave (classic chiptune)
                let wave = sin(2 * .pi * freq * t) >= 0 ? 1.0 : -1.0
                data[i] = Float(wave * env * 0.3)
            }
        }

        return buffer
    }

    // MARK: - Sound Synthesis (8-bit pixel style)

    /// pitchStep：音高阶梯（每级 +2 半音，封顶 +8 级），用于 match 大小 / 连锁层级的听感递进。
    /// 连续消除音调越来越高是三消"爽感"的核心听觉反馈（Candy Crush 同款手法）。
    func play(_ sound: SoundEffect, pitchStep: Int = 0) {
        guard PlayerData.shared.soundEnabled else { return }
        let step = max(0, min(pitchStep, 8))
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.synthesize(sound, pitchStep: step)
        }
    }

    private func synthesize(_ sound: SoundEffect, pitchStep: Int = 0) {
        let buffer = makeBuffer(for: sound, pitchStep: pitchStep)
        guard let buf = buffer else { return }

        if !isEngineRunning {
            try? engine.start()
            isEngineRunning = true
        }

        playerNode.scheduleBuffer(buf, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    private func makeBuffer(for sound: SoundEffect, pitchStep: Int = 0) -> AVAudioPCMBuffer? {
        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        var params = sound.params
        if pitchStep > 0 {
            // 每级 +2 半音：ratio = 2^(step*2/12)
            let ratio = pow(2.0, Double(pitchStep) * 2.0 / 12.0)
            params.startFreq *= ratio
            params.endFreq *= ratio
        }
        let frameCount = AVAudioFrameCount(sampleRate * params.duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return nil }

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / params.duration

            // Envelope (attack-decay-sustain-release)
            let envelope: Double
            if t < params.attack {
                envelope = t / params.attack
            } else if t < params.attack + params.decay {
                let d = (t - params.attack) / params.decay
                envelope = 1.0 - d * (1 - params.sustain)
            } else if t < params.duration - params.release {
                envelope = params.sustain
            } else {
                let r = (t - (params.duration - params.release)) / params.release
                envelope = params.sustain * (1 - r)
            }

            // Frequency with optional slide
            let freq = params.startFreq + (params.endFreq - params.startFreq) * progress

            // Waveform
            let wave: Double
            switch params.waveform {
            case .square:
                wave = sin(2 * .pi * freq * t) >= 0 ? 1.0 : -1.0
            case .sine:
                wave = sin(2 * .pi * freq * t)
            case .triangle:
                let p = freq * t
                wave = 2 * abs(2 * (p - floor(p + 0.5))) - 1
            case .noise:
                wave = Double.random(in: -1...1)
            }

            data[i] = Float(wave * envelope * params.volume)
        }

        return buffer
    }
}

// MARK: - Sound Definitions

enum Waveform { case square, sine, triangle, noise }

struct SoundParams {
    var startFreq: Double
    var endFreq: Double
    var duration: Double
    var attack: Double
    var decay: Double
    var sustain: Double
    var release: Double
    var volume: Double
    var waveform: Waveform
}

enum SoundEffect {
    case swap, match, specialCreated, cascade, levelWin, levelFail
    case buttonTap, boosterUse, coinCollect, starEarn
    case tileSelect, invalidSwap, shuffle, colorBomb

    var params: SoundParams {
        switch self {
        case .tileSelect:
            return SoundParams(startFreq:440, endFreq:880, duration:0.08,
                               attack:0.01, decay:0.02, sustain:0.3, release:0.05, volume:0.4, waveform:.square)
        case .swap:
            return SoundParams(startFreq:600, endFreq:900, duration:0.12,
                               attack:0.01, decay:0.04, sustain:0.5, release:0.07, volume:0.5, waveform:.square)
        case .invalidSwap:
            return SoundParams(startFreq:200, endFreq:150, duration:0.15,
                               attack:0.01, decay:0.05, sustain:0.2, release:0.09, volume:0.4, waveform:.square)
        case .match:
            return SoundParams(startFreq:523, endFreq:1047, duration:0.18,
                               attack:0.01, decay:0.05, sustain:0.6, release:0.12, volume:0.6, waveform:.square)
        case .specialCreated:
            return SoundParams(startFreq:880, endFreq:1760, duration:0.25,
                               attack:0.02, decay:0.08, sustain:0.7, release:0.15, volume:0.7, waveform:.sine)
        case .cascade:
            return SoundParams(startFreq:700, endFreq:1400, duration:0.20,
                               attack:0.01, decay:0.06, sustain:0.6, release:0.13, volume:0.55, waveform:.square)
        case .colorBomb:
            return SoundParams(startFreq:200, endFreq:2000, duration:0.5,
                               attack:0.05, decay:0.1, sustain:0.8, release:0.35, volume:0.8, waveform:.sine)
        case .boosterUse:
            return SoundParams(startFreq:1000, endFreq:2000, duration:0.3,
                               attack:0.02, decay:0.1, sustain:0.6, release:0.18, volume:0.7, waveform:.sine)
        case .shuffle:
            return SoundParams(startFreq:300, endFreq:600, duration:0.4,
                               attack:0.05, decay:0.1, sustain:0.5, release:0.25, volume:0.5, waveform:.triangle)
        case .levelWin:
            return SoundParams(startFreq:523, endFreq:2093, duration:0.8,
                               attack:0.05, decay:0.1, sustain:0.8, release:0.65, volume:0.8, waveform:.sine)
        case .levelFail:
            return SoundParams(startFreq:392, endFreq:196, duration:0.8,
                               attack:0.05, decay:0.1, sustain:0.5, release:0.65, volume:0.7, waveform:.triangle)
        case .buttonTap:
            return SoundParams(startFreq:800, endFreq:1200, duration:0.08,
                               attack:0.005, decay:0.02, sustain:0.3, release:0.055, volume:0.4, waveform:.square)
        case .coinCollect:
            return SoundParams(startFreq:1047, endFreq:2093, duration:0.15,
                               attack:0.01, decay:0.04, sustain:0.6, release:0.1, volume:0.6, waveform:.sine)
        case .starEarn:
            return SoundParams(startFreq:659, endFreq:1319, duration:0.35,
                               attack:0.02, decay:0.08, sustain:0.7, release:0.25, volume:0.7, waveform:.sine)
        }
    }
}
