import Foundation
import SwiftUI

/// Hub A 面（Lumina 任务）与 Rahmi B 面切换；由 `/v1/version_config` 的 `type` 驱动。
@MainActor
final class AppFaceController: ObservableObject {
    enum Face: String {
        case lumina
        case rahmi
    }

    private static let unlockKey = "hub.rahmi.bface.unlocked"
    private static let lastFaceKey = "hub.app.lastFace"

    @Published private(set) var activeFace: Face
    @Published private(set) var hubPresentationType: Int
    @Published var rahmiHasBootstrapped = false

    init() {
        let type = VersionConfigStore.readPersistedPresentationType()
        hubPresentationType = type
        activeFace = Self.initialFace(forPresentationType: type)
    }

    static var isBFaceUnlocked: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: unlockKey)
            || VersionConfigStore.readPersistedPresentationType() == 2
        #endif
    }

    /// Release 不展示手动 Hub/Rahmi 悬浮切换；仅 Debug 用于联调。
    static var showsManualFaceSwitchInUI: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    var isShowingRahmi: Bool { activeFace == .rahmi }

    /// `type != 2` 时允许手动进入 Rahmi（需额外解锁）；`type == 2` 由远端固定 Rahmi
    var allowsManualRahmiEntry: Bool { hubPresentationType != 2 }

    /// `type == 2` 时由远端固定 Rahmi，不展示返回 Hub 入口
    var allowsManualHubReturn: Bool { hubPresentationType != 2 }

    func unlockBFace() {
        UserDefaults.standard.set(true, forKey: Self.unlockKey)
    }

    /// 根据 `version_config.type` 切换 Hub / Rahmi（2 → Rahmi，否则 → Hub）
    func applyPresentationType(_ type: Int) {
        guard type == 1 || type == 2 else { return }
        hubPresentationType = type

        if type == 2 {
            unlockBFace()
            if activeFace != .rahmi {
                activeFace = .rahmi
                persistFace()
            }
        } else if activeFace != .lumina {
            activeFace = .lumina
            persistFace()
        }
    }

    func switchToLumina() {
        guard activeFace != .lumina else { return }
        activeFace = .lumina
        persistFace()
    }

    func switchToRahmi() {
        unlockBFace()
        guard activeFace != .rahmi else { return }
        activeFace = .rahmi
        persistFace()
    }

    func toggleFace() {
        if activeFace == .lumina {
            switchToRahmi()
        } else {
            switchToLumina()
        }
    }

    func markRahmiBootstrapped() {
        rahmiHasBootstrapped = true
    }

    private static func initialFace(forPresentationType type: Int) -> Face {
        if type == 2, isBFaceUnlocked { return .rahmi }
        return .lumina
    }

    private func persistFace() {
        UserDefaults.standard.set(activeFace.rawValue, forKey: Self.lastFaceKey)
    }
}
