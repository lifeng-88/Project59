import Foundation

/// Hub A 面演示任务 / 重置入口：仅 Debug 启用。
enum HubDemoData {
    static var isEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var versionLabel: String {
        "v\(version)"
    }
}
