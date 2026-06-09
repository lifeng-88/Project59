import SwiftUI

// MARK: - 语言环境

extension AppLanguage {
    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

private struct HubLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .zhHans
}

extension EnvironmentValues {
    var hubLanguage: AppLanguage {
        get { self[HubLanguageKey.self] }
        set { self[HubLanguageKey.self] = newValue }
    }
}

// MARK: - 文案表（可逐步迁移到 Localizable.strings）

enum L10n {
    static func tr(_ key: Key, language: AppLanguage) -> String {
        table[language]?[key] ?? table[.zhHans]?[key] ?? key.rawValue
    }

    enum Key: String {
        case tabToday, tabCalendar, tabInsights, tabSettings
        case todayTitle, todaySearch, todayRemaining, todayCompleted, todayAddFirst
        case calendarEmptyTitle, calendarAddTask, calendarStartFocus, calendarToday
        case menuNav, menuShortcuts, menuNewTask, menuStartFocus, menuClose
        case focusTimerTitle, focusPhaseWork, focusPhaseShortBreak, focusPhaseLongBreak
        case focusDeepModeOn, focusCompletedCount, focusEnd, focusStart, focusPause
        case focusSkipBreak, focusClose, focusFocusing, focusShortBreak, focusLongBreak
        case notifyPomodoroTitle, notifyPomodoroBody, notifyBreakTitle, notifyBreakBody
        case settingsStreakDays
    }

    private static let table: [AppLanguage: [Key: String]] = [
        .zhHans: [
            .tabToday: "今日",
            .tabCalendar: "日历",
            .tabInsights: "分析",
            .tabSettings: "设置",
            .todayTitle: "今日",
            .todaySearch: "搜索任务",
            .todayRemaining: "今天还有 %d 个任务待办",
            .todayCompleted: "已完成",
            .todayAddFirst: "添加第一个任务",
            .calendarEmptyTitle: "这一天还没有任务",
            .calendarAddTask: "添加任务",
            .calendarStartFocus: "开始专注",
            .calendarToday: "今天",
            .menuNav: "导航",
            .menuShortcuts: "快捷操作",
            .menuNewTask: "新建任务",
            .menuStartFocus: "开始专注",
            .menuClose: "关闭",
            .focusTimerTitle: "专注计时",
            .focusPhaseWork: "专注中",
            .focusPhaseShortBreak: "短休息",
            .focusPhaseLongBreak: "长休息",
            .focusDeepModeOn: "深度专注模式已开启",
            .focusCompletedCount: "已完成 %d 个番茄钟",
            .focusEnd: "结束",
            .focusStart: "开始",
            .focusPause: "暂停",
            .focusSkipBreak: "跳过休息，继续专注",
            .focusClose: "关闭",
            .focusFocusing: "专注中",
            .focusShortBreak: "短暂休息",
            .focusLongBreak: "长时休息",
            .notifyPomodoroTitle: "番茄钟完成",
            .notifyPomodoroBody: "太棒了！休息 %d 分钟后再继续。",
            .notifyBreakTitle: "休息结束",
            .notifyBreakBody: "准备好开始下一轮专注了吗？",
            .settingsStreakDays: "连续专注"
        ],
        .en: [
            .tabToday: "Today",
            .tabCalendar: "Calendar",
            .tabInsights: "Insights",
            .tabSettings: "Settings",
            .todayTitle: "Today",
            .todaySearch: "Search tasks",
            .todayRemaining: "%d tasks left for today",
            .todayCompleted: "Completed",
            .todayAddFirst: "Add your first task",
            .calendarEmptyTitle: "No tasks on this day",
            .calendarAddTask: "Add task",
            .calendarStartFocus: "Start focus",
            .calendarToday: "Today",
            .menuNav: "Navigation",
            .menuShortcuts: "Shortcuts",
            .menuNewTask: "New task",
            .menuStartFocus: "Start focus",
            .menuClose: "Close",
            .focusTimerTitle: "Focus timer",
            .focusPhaseWork: "Focusing",
            .focusPhaseShortBreak: "Short break",
            .focusPhaseLongBreak: "Long break",
            .focusDeepModeOn: "Deep focus mode is on",
            .focusCompletedCount: "%d pomodoros completed",
            .focusEnd: "End",
            .focusStart: "Start",
            .focusPause: "Pause",
            .focusSkipBreak: "Skip break, focus again",
            .focusClose: "Close",
            .focusFocusing: "In focus",
            .focusShortBreak: "Short break",
            .focusLongBreak: "Long break",
            .notifyPomodoroTitle: "Pomodoro complete",
            .notifyPomodoroBody: "Nice work! Take a %d-minute break.",
            .notifyBreakTitle: "Break over",
            .notifyBreakBody: "Ready for another focus session?",
            .settingsStreakDays: "Focus streak"
        ]
    ]
}

extension HubTab {
    func title(language: AppLanguage) -> String {
        switch self {
        case .today: return L10n.tr(.tabToday, language: language)
        case .calendar: return L10n.tr(.tabCalendar, language: language)
        case .insights: return L10n.tr(.tabInsights, language: language)
        case .settings: return L10n.tr(.tabSettings, language: language)
        }
    }
}
