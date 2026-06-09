import Foundation

/// 专注计时持久化，支持前后台切换后恢复剩余时间
struct PersistedFocusSession: Codable, Equatable {
    enum Phase: String, Codable {
        case work, shortBreak, longBreak
    }

    var phase: Phase
    /// 运行中时为目标结束时间；暂停时为 nil
    var phaseEndDate: Date?
    var secondsRemaining: Int
    var totalPhaseSeconds: Int
    var completedPomodoros: Int
    var isRunning: Bool
}

enum FocusSessionStore {
    private static let key = "hub.activeFocusSession"

    static func load() -> PersistedFocusSession? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PersistedFocusSession.self, from: data)
    }

    static func save(_ session: PersistedFocusSession?) {
        if let session {
            guard let data = try? JSONEncoder().encode(session) else { return }
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
