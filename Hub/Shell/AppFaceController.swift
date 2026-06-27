import Foundation
import SwiftUI

/// Hub A 面（Lumina）、B 面（Rahmi）、C 面（WebView）；由 `/v1/app_config` 的 `type` 驱动。
@MainActor
final class AppFaceController: ObservableObject {
    enum Face: String {
        case lumina
        case rahmi
        case web
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
            || VersionConfigStore.readPersistedPresentationType() == 3
        #endif
    }

    /// Release 不展示手动 Hub/Rahmi/Web 悬浮切换；仅 Debug 用于联调。
    static var showsManualFaceSwitchInUI: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    var isShowingRahmi: Bool { activeFace == .rahmi }
    var isShowingWeb: Bool { activeFace == .web }

    /// `type != 3` 时允许手动进入 Rahmi；`type == 3` 由远端固定 Rahmi
    var allowsManualRahmiEntry: Bool { hubPresentationType != 3 }

    /// `type == 2/3` 时由远端固定 C 面 / B 面，不展示返回 Hub 入口
    var allowsManualHubReturn: Bool { hubPresentationType != 2 && hubPresentationType != 3 }

    func unlockBFace() {
        UserDefaults.standard.set(true, forKey: Self.unlockKey)
    }

    /// 根据 `app_config.type` 切换 Hub / Web / Rahmi（1→Hub，2→Web，3→Rahmi）
    func applyPresentationType(_ type: Int) {
        guard type == 1 || type == 2 || type == 3 else { return }
        hubPresentationType = type

        switch type {
        case 2:
            if activeFace != .web {
                activeFace = .web
                persistFace()
            }
        case 3:
            unlockBFace()
            if activeFace != .rahmi {
                activeFace = .rahmi
                persistFace()
            }
        default:
            if activeFace != .lumina {
                activeFace = .lumina
                persistFace()
            }
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

    func switchToWeb() {
        guard activeFace != .web else { return }
        activeFace = .web
        persistFace()
    }

    func toggleFace() {
        if activeFace == .lumina {
            switchToRahmi()
        } else {
            switchToLumina()
        }
    }

    /// DEBUG：Hub → Rahmi → Web → Hub
    func cycleFace() {
        #if DEBUG
        switch activeFace {
        case .lumina:
            unlockBFace()
            activeFace = .rahmi
        case .rahmi:
            activeFace = .web
        case .web:
            activeFace = .lumina
        }
        persistFace()
        #else
        toggleFace()
        #endif
    }

    func markRahmiBootstrapped() {
        rahmiHasBootstrapped = true
    }

    private static func initialFace(forPresentationType type: Int) -> Face {
        switch type {
        case 3 where isBFaceUnlocked:
            return .rahmi
        case 2:
            return .web
        default:
            return .lumina
        }
    }

    private func persistFace() {
        UserDefaults.standard.set(activeFace.rawValue, forKey: Self.lastFaceKey)
    }
}
