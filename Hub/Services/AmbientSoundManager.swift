import AVFoundation
import Combine

@MainActor
final class AmbientSoundManager: ObservableObject {
    static let shared = AmbientSoundManager()

    @Published private(set) var playingSound: AmbientSound?

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?

    private init() {}

    func toggle(_ sound: AmbientSound) {
        if playingSound == sound {
            stop()
        } else {
            play(sound)
        }
    }

    func play(_ sound: AmbientSound) {
        stop()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return
        }

        let engine = AVAudioEngine()
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let soundType = sound

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = Self.sample(for: soundType, frame: frame)
                for buffer in abl {
                    guard let ptr = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    ptr[frame] = sample
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.35

        do {
            try engine.start()
            self.engine = engine
            self.sourceNode = node
            playingSound = sound
        } catch {
            stop()
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
        sourceNode = nil
        playingSound = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func sample(for sound: AmbientSound, frame: Int) -> Float {
        let t = Float(frame)
        switch sound {
        case .whiteNoise:
            return Float.random(in: -0.15...0.15)
        case .rain:
            let base = Float.random(in: -0.12...0.12)
            let drip = sin(t * 0.02) * 0.04
            return base + drip
        case .forest:
            let wind = sin(t * 0.005) * 0.06
            let bird = sin(t * 0.08) * Float.random(in: 0...0.03)
            return wind + bird + Float.random(in: -0.04...0.04)
        case .cafe:
            let hum = sin(t * 0.01) * 0.05
            return hum + Float.random(in: -0.1...0.1)
        }
    }
}
