import Foundation
import AVFoundation
import Combine

/// 程序化音频：不含任何版权音乐文件。
/// 背景音乐为古风五声音阶（宫商角徵羽）旋律，用正弦波合成后循环播放；
/// 音效同样由合成音色实现。
final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var musicEnabled: Bool = true { didSet { musicEnabled ? startMusic() : stopMusic() } }
    @Published var musicVolume: Float = 0.35 { didSet { musicPlayer.volume = musicVolume } }
    @Published var sfxEnabled: Bool = true

    private let engine = AVAudioEngine()
    private let musicPlayer = AVAudioPlayerNode()
    private let sfxPlayer = AVAudioPlayerNode()
    private var musicTimer: Timer?
    private var melodyIndex = 0
    private var isEngineRunning = false

    // 五声音阶（C 大调五声：C D E G A），单位 Hz
    // 宫 C4 261.63 / 商 D4 293.66 / 角 E4 329.63 / 徵 G4 392.00 / 羽 A4 440.00
    private let scale: [String: Double] = [
        "C4": 261.63, "D4": 293.66, "E4": 329.63, "G4": 392.00, "A4": 440.00,
        "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.00,
        "G3": 196.00, "A3": 220.00, "E3": 164.81, "C3": 130.81
    ]
    /// 一段原创的古风五声旋律：(音名, 拍数)，0.42 秒/拍，循环播放
    private let melody: [(String, Double)] = [
        ("E5", 1), ("D5", 1), ("C5", 2), ("A4", 1), ("G4", 1),
        ("A4", 2), ("C5", 1), ("E5", 1), ("D5", 2), ("C5", 1),
        ("A4", 1), ("G4", 2), ("E4", 1), ("D4", 1), ("C4", 2),
        ("D4", 1), ("E4", 1), ("G4", 2), ("A4", 1), ("G4", 1),
        ("E4", 2), ("D4", 1), ("C4", 3), ("G3", 1),
    ]
    private let bass: [(String, Double)] = [
        ("C3", 4), ("G3", 4), ("A3", 4), ("E3", 4),
        ("C3", 4), ("G3", 4), ("A3", 4), ("G3", 4),
    ]

    private init() {
        setupEngine()
    }

    private func setupEngine() {
        engine.attach(musicPlayer)
        engine.attach(sfxPlayer)
        let mixer = engine.mainMixerNode
        engine.connect(musicPlayer, to: mixer, format: nil)
        engine.connect(sfxPlayer, to: mixer, format: nil)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func ensureEngineRunning() {
        guard !isEngineRunning else { return }
        do {
            try engine.start()
            isEngineRunning = true
        } catch {
            print("Audio engine start error: \(error)")
        }
    }

    /// 生成一段正弦波（含淡入淡出包络，避免爆音）
    private func toneBuffer(freq: Double, duration: Double, volume: Float, sampleRate: Double = 44100) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        guard let channel = buffer.floatChannelData?[0] else { return buffer }
        let fade = Int(sampleRate * 0.02)
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            // 基音 + 二次谐波，音色更接近笛/古筝的柔和感
            var sample = sin(2 * .pi * freq * t) + 0.3 * sin(4 * .pi * freq * t)
            sample *= 0.7
            let fadeIn = min(1.0, Double(i) / Double(max(fade, 1)))
            let fadeOut = min(1.0, Double(Int(frames) - i) / Double(max(fade, 1)))
            channel[i] = Float(sample) * volume * Float(min(fadeIn, fadeOut))
        }
        return buffer
    }

    private func playTone(freq: Double, duration: Double, volume: Float, on player: AVAudioPlayerNode) {
        ensureEngineRunning()
        let buffer = toneBuffer(freq: freq, duration: duration, volume: volume)
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    // MARK: 背景音乐
    func startMusic() {
        guard musicEnabled else { return }
        ensureEngineRunning()
        musicPlayer.volume = musicVolume
        stopMusicTimer()
        melodyIndex = 0
        scheduleNextNote()
    }

    func stopMusic() {
        stopMusicTimer()
        musicPlayer.stop()
    }

    private func stopMusicTimer() {
        musicTimer?.invalidate()
        musicTimer = nil
    }

    private func scheduleNextNote() {
        guard musicEnabled else { return }
        let (name, beats) = melody[melodyIndex % melody.count]
        let freq = scale[name] ?? 440
        let duration = beats * 0.42
        // 主旋律 + 低八度根音（每 4 拍换一次低音）
        playTone(freq: freq, duration: duration, volume: 0.5, on: musicPlayer)
        let bassIndex = (melodyIndex / 8) % bass.count
        let bassFreq = scale[bass[bassIndex].0] ?? 130.81
        if melodyIndex % 8 == 0 {
            playTone(freq: bassFreq, duration: duration * 4, volume: 0.25, on: musicPlayer)
        }
        melodyIndex += 1
        musicTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.scheduleNextNote()
        }
    }

    // MARK: 音效
    func playMoveSound() {
        guard sfxEnabled else { return }
        // 走子：清脆的“笃”声，木质敲击感（短促 880Hz + 快速衰减）
        playTone(freq: 880, duration: 0.08, volume: 0.9, on: sfxPlayer)
        playTone(freq: 440, duration: 0.06, volume: 0.5, on: sfxPlayer)
    }

    func playCaptureSound() {
        guard sfxEnabled else { return }
        // 吃子：低沉有力的两声
        playTone(freq: 320, duration: 0.12, volume: 0.9, on: sfxPlayer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { [weak self] in
            guard let self else { return }
            self.playTone(freq: 180, duration: 0.15, volume: 0.8, on: self.sfxPlayer)
        }
    }

    func playCheckSound() {
        guard sfxEnabled else { return }
        // 将军：高亮的两声提醒
        playTone(freq: 1046, duration: 0.12, volume: 0.8, on: sfxPlayer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            self.playTone(freq: 1318, duration: 0.18, volume: 0.8, on: self.sfxPlayer)
        }
    }

    func playWinSound() {
        guard sfxEnabled else { return }
        // 胜利：上行五声音阶琶音
        let notes = [523.25, 587.33, 659.25, 783.99, 1046.50]
        for (i, f) in notes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) { [weak self] in
                guard let self else { return }
                self.playTone(freq: f, duration: 0.25, volume: 0.7, on: self.sfxPlayer)
            }
        }
    }

    func playLoseSound() {
        guard sfxEnabled else { return }
        // 失败：下行三音
        let notes = [392.00, 329.63, 261.63]
        for (i, f) in notes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) { [weak self] in
                guard let self else { return }
                self.playTone(freq: f, duration: 0.3, volume: 0.7, on: self.sfxPlayer)
            }
        }
    }

    func playSelectSound() {
        guard sfxEnabled else { return }
        playTone(freq: 660, duration: 0.05, volume: 0.4, on: sfxPlayer)
    }
}
