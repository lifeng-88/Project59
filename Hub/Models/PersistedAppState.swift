import Foundation

struct PersistedAppState: Codable {
    var tasks: [HubTask]
    var notificationsEnabled: Bool
    var pomodoroMinutes: Int
    var breakMinutes: Int
    var longBreakMinutes: Int
    var deepFocusEnabled: Bool
    var selectedAmbientSound: AmbientSound?
    var cloudSyncEnabled: Bool
    var appTheme: HubAppearanceTheme
    var focusStreakDays: Int
    var lastFocusActivityDate: Date?
    var totalFocusMinutes: Int
    var focusGoalMinutes: Int?
    var hasLoadedSampleData: Bool
    var userName: String?
    var userEmail: String?
    var appLanguage: AppLanguage?

    static let empty = PersistedAppState(
        tasks: [],
        notificationsEnabled: true,
        pomodoroMinutes: 25,
        breakMinutes: 5,
        longBreakMinutes: 15,
        deepFocusEnabled: true,
        selectedAmbientSound: .rain,
        cloudSyncEnabled: true,
        appTheme: .light,
        focusStreakDays: 0,
        lastFocusActivityDate: nil,
        totalFocusMinutes: 0,
        focusGoalMinutes: 1200,
        hasLoadedSampleData: false,
        userName: "张伟",
        userEmail: "zhangwei@lumina.io",
        appLanguage: .zhHans
    )
}

enum AppPersistence {
    private static let key = "hub.persistedState"

    static func load() -> PersistedAppState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PersistedAppState.self, from: data)
    }

    static func save(_ state: PersistedAppState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
