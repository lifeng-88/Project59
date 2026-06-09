import AVFoundation
import UIKit

/// Rahmi B 面一次性初始化（原 `RahmiApp.init` 逻辑）
enum RahmiModule {
    private static var didConfigure = false

    @MainActor
    static func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        BBBNavigationChrome.applyGlobalTint()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[RahmiModule] AVAudioSession setup failed: \(error)")
        }
    }
}
