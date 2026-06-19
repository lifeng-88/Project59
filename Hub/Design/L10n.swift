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

    static func hubErrorMessage(_ error: Error, language: AppLanguage) -> String {
        if let error = error as? DataImportService.ImportError {
            return error.message(language: language)
        }
        if let error = error as? CloudSyncService.SyncError {
            return error.message(language: language)
        }
        if let error = error as? ProfileImageStore.StoreError {
            return error.message(language: language)
        }
        return error.localizedDescription
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
        // Settings
        case settingsTitle, settingsAllTasks, settingsCompleted, settingsStreakDayUnit
        case settingsProfile, settingsEdit, settingsPreferences, settingsLanguage
        case settingsTheme, settingsFocusGoal, settingsFocusGoalHours
        case settingsNotifications, settingsNotificationsSubtitle, settingsNotificationsDenied
        case settingsOpenSystemSettings, settingsFocusSection, settingsFocusModeSettings
        case settingsFocusSummary, settingsAboutFocus, settingsAboutFocusSubtitle
        case settingsStartFocusNow, settingsDataSection, settingsCloudSync
        case settingsDataManagement, settingsDataManagementSubtitle
        case settingsLastSync, settingsAutoBackup, settingsNotEnabled
        case settingsAboutSection, settingsVersion, settingsPrivacy
        case settingsRateApp, settingsRateAppSubtitle, settingsHelp
        case settingsResetDemo, settingsResetTitle, settingsResetMessage, settingsResetDone, settingsResetConfirmAction
        case commonCancel, commonSave, commonDone, commonClose
        // Theme picker
        case themeLight, themeDark, themeSystem
        case themeLightSubtitle, themeDarkSubtitle, themeSystemSubtitle
        case themePreview, themePreviewLight, themePreviewDark
        // Focus goal sheet
        case focusGoalHint, focusGoalPickerHours, focusGoalSubtitleFormatted
        // Profile edit
        case profileEditTitle, profileBasicInfo, profileName, profileEmail, profileRemoveAvatar
        // Data management
        case dataBackupSection, dataExport, dataImport, dataUploadCloud, dataRestoreCloud
        case dataCloudSyncToggle, dataLastSyncInline, dataCloudFooter, dataNavTitle
        case dataExportFormat, dataExportJSON, dataExportCSV
        case dataRestoreTitle, dataRestoreAction, dataRestoreMessage
        // Alerts
        case alertUploadedCloud, alertNoCloudBackup, alertImportedTasks, alertRestoredBackup
        case alertRestoredCloud, alertProfileUpdated, alertNotificationDenied
        case alertExportFailed, alertSyncedCloud
        // Focus settings
        case focusModeTitle, focusPomodoroSettings, focusDuration, focusMinutesUnit
        case focusEnhanceSection, focusDeepMode, focusDeepModeSubtitle
        case focusAmbientSection, focusSettingsEffectiveHint
        // Focus guide
        case focusGuideReady, focusGuideWhatIs, focusGuideIntro, focusGuideHowTo
        case focusGuideStep1Title, focusGuideStep1Detail
        case focusGuideStep2Title, focusGuideStep2Detail
        case focusGuideStep3Title, focusGuideStep3Detail
        case focusGuideStep4Title, focusGuideStep4Detail
        case focusGuideTips, focusGuideTip1, focusGuideTip2, focusGuideTip3
        // Ambient sounds
        case ambientRain, ambientForest, ambientWhiteNoise, ambientCafe
        case ambientRainSubtitle, ambientForestSubtitle, ambientWhiteNoiseSubtitle, ambientCafeSubtitle
        // Privacy policy
        case privacyDataCollection, privacyDataCollectionBody
        case privacyNotificationsSection, privacyNotificationsBody
        case privacyThirdParty, privacyThirdPartyBody
        // Task metadata
        case categoryWork, categoryDeepFocus, categoryPersonal
        case priorityLow, priorityMedium, priorityHigh
        // Common actions
        case commonEdit, commonDelete, commonTip, commonOK
        // Today
        case todayEmptyNoTasks, todayEmptyNoResults, todayInspiration
        // Calendar extras
        case calendarPendingTasks, calendarNoSchedule, calendarAllDay, calendarDaySelected
        case priorityBadge, priorityLevelSuffix
        // Task forms
        case quickAddPlaceholder, taskTitlePlaceholder, editTaskTitle
        case setDate, setReminder, dateLabel, reminderTimeLabel, chooseCategory, prioritySection
        case noDate, noPriority, noReminder
        // Insights
        case insightsTitle, insightsProductivityScore, insightsBasedOnTasks
        case insightsCompletedTasks, insightsFocusDuration, insightsCurrentStreak
        case insightsStreakDaysUnit, insightsFocusDistribution, insightsKeepGoing
        case insightsStreakMessage, insightsStartSmall
        case focusHoursFormatted
        // Errors
        case errorInvalidFormat, errorEmptyCSV, errorInvalidCSVHeader
        case alertImportedCSV
        case errorICloudUnavailable, errorEncodingFailed, errorAvatarSaveFailed
        // Notifications
        case notifyTaskReminderTitle
        // Face switch
        case faceSwitchToRahmi, faceSwitchToHub
        // Demo content
        case demoUserName
        case sampleTaskDesign, sampleTaskDeepWork, sampleTaskShopping
        case sampleTaskMeditation, sampleTaskEmail
    }

    static func weekdaySymbols(language: AppLanguage) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = language.locale
        return calendar.veryShortWeekdaySymbols
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
            .settingsStreakDays: "连续专注",
            .settingsTitle: "设置",
            .settingsAllTasks: "全部任务",
            .settingsCompleted: "已完成",
            .settingsStreakDayUnit: "%d天",
            .settingsProfile: "个人资料",
            .settingsEdit: "编辑",
            .settingsPreferences: "偏好设置",
            .settingsLanguage: "语言",
            .settingsTheme: "主题模式",
            .settingsFocusGoal: "专注目标",
            .settingsFocusGoalHours: "%d 小时",
            .settingsNotifications: "提醒通知",
            .settingsNotificationsSubtitle: "任务提醒将准时推送",
            .settingsNotificationsDenied: "通知已关闭，请在系统设置中开启",
            .settingsOpenSystemSettings: "前往系统设置",
            .settingsFocusSection: "专注模式",
            .settingsFocusModeSettings: "专注模式设置",
            .settingsFocusSummary: "%d 分钟专注 · %d 分钟休息",
            .settingsAboutFocus: "关于专注模式",
            .settingsAboutFocusSubtitle: "番茄工作法与使用技巧",
            .settingsStartFocusNow: "立即开始专注",
            .settingsDataSection: "数据与备份",
            .settingsCloudSync: "云端同步",
            .settingsDataManagement: "数据管理",
            .settingsDataManagementSubtitle: "导出、导入与 iCloud",
            .settingsLastSync: "上次同步 %@",
            .settingsAutoBackup: "自动备份到 iCloud",
            .settingsNotEnabled: "未开启",
            .settingsAboutSection: "关于应用",
            .settingsVersion: "版本号",
            .settingsPrivacy: "隐私政策",
            .settingsRateApp: "评价应用",
            .settingsRateAppSubtitle: "您的反馈帮助我们改进",
            .settingsHelp: "帮助与支持",
            .settingsResetDemo: "重置演示数据",
            .settingsResetTitle: "重置所有数据？",
            .settingsResetMessage: "将清除当前任务并恢复示例内容，此操作不可撤销。",
            .settingsResetDone: "已恢复为演示数据",
            .settingsResetConfirmAction: "重置",
            .commonCancel: "取消",
            .commonSave: "保存",
            .commonDone: "完成",
            .commonClose: "关闭",
            .themeLight: "浅色模式",
            .themeDark: "深色模式",
            .themeSystem: "跟随系统",
            .themeLightSubtitle: "始终使用浅色界面",
            .themeDarkSubtitle: "始终使用深色界面",
            .themeSystemSubtitle: "随系统外观自动切换",
            .themePreview: "预览",
            .themePreviewLight: "浅色",
            .themePreviewDark: "深色",
            .focusGoalHint: "设定每周专注时长目标，用于分析页进度展示。",
            .focusGoalPickerHours: "%d 小时",
            .focusGoalSubtitleFormatted: "目标：%d小时",
            .profileEditTitle: "编辑资料",
            .profileBasicInfo: "基本信息",
            .profileName: "姓名",
            .profileEmail: "邮箱",
            .profileRemoveAvatar: "移除头像",
            .dataBackupSection: "备份与恢复",
            .dataExport: "导出数据",
            .dataImport: "导入备份",
            .dataUploadCloud: "上传到 iCloud",
            .dataRestoreCloud: "从 iCloud 恢复",
            .dataCloudSyncToggle: "云端同步",
            .dataLastSyncInline: "上次同步：%@",
            .dataCloudFooter: "开启后，任务与设置将自动备份到 iCloud Drive。",
            .dataNavTitle: "数据与备份",
            .dataExportFormat: "导出格式",
            .dataExportJSON: "JSON（含设置）",
            .dataExportCSV: "CSV（任务列表）",
            .dataRestoreTitle: "从 iCloud 恢复？",
            .dataRestoreAction: "恢复",
            .dataRestoreMessage: "将用 iCloud 备份覆盖当前本地数据，此操作不可撤销。",
            .alertUploadedCloud: "已上传到 iCloud",
            .alertNoCloudBackup: "iCloud 中暂无备份文件",
            .alertImportedTasks: "已导入 %d 条任务",
            .alertRestoredBackup: "已恢复备份数据",
            .alertRestoredCloud: "已从 iCloud 恢复",
            .alertProfileUpdated: "资料已更新",
            .alertNotificationDenied: "请在系统设置中允许 Hub 发送通知",
            .alertExportFailed: "导出失败：%@",
            .alertSyncedCloud: "已同步到 iCloud",
            .focusModeTitle: "专注模式",
            .focusPomodoroSettings: "番茄钟设置",
            .focusDuration: "专注时长",
            .focusMinutesUnit: "%d 分钟",
            .focusEnhanceSection: "专注增强",
            .focusDeepMode: "深度专注模式",
            .focusDeepModeSubtitle: "开启后将屏蔽所有非紧急通知",
            .focusAmbientSection: "专注环境音",
            .focusSettingsEffectiveHint: "设置将在下次进入专注模式时生效",
            .focusGuideReady: "准备好开始您的第一个番茄钟了吗？",
            .focusGuideWhatIs: "什么是番茄工作法？",
            .focusGuideIntro: "番茄工作法（Pomodoro Technique）是一种简单易行的延时管理方法。通过将工作时间切分为 25 分钟的「番茄钟」和 5 分钟的休息，帮助您保持高强度的专注，同时避免过度疲劳。",
            .focusGuideHowTo: "如何使用",
            .focusGuideStep1Title: "选择任务",
            .focusGuideStep1Detail: "从今日列表中挑选一项需要专注完成的任务。",
            .focusGuideStep2Title: "启动番茄钟",
            .focusGuideStep2Detail: "设置 25 分钟计时，期间避免一切干扰。",
            .focusGuideStep3Title: "短休息",
            .focusGuideStep3Detail: "计时结束后休息 5 分钟，起身活动、补充水分。",
            .focusGuideStep4Title: "循环重复",
            .focusGuideStep4Detail: "完成 4 个番茄钟后，进行一次 15–30 分钟的长休息。",
            .focusGuideTips: "专注小贴士",
            .focusGuideTip1: "开启勿扰模式，将手机翻面放置。",
            .focusGuideTip2: "番茄钟开始前准备好饮用水。",
            .focusGuideTip3: "休息时远离屏幕，做简单的伸展运动。",
            .ambientRain: "雨声",
            .ambientForest: "森林",
            .ambientWhiteNoise: "白噪音",
            .ambientCafe: "咖啡馆",
            .ambientRainSubtitle: "窗外的绵绵细雨",
            .ambientForestSubtitle: "清晨的鸟鸣与微风",
            .ambientWhiteNoiseSubtitle: "平稳舒适的基础背景",
            .ambientCafeSubtitle: "温和的背景感",
            .privacyDataCollection: "数据收集",
            .privacyDataCollectionBody: "Hub 将任务与偏好设置存储在您的设备本地。若开启 iCloud 同步，数据会加密保存在您的 iCloud 账户中。",
            .privacyNotificationsSection: "通知",
            .privacyNotificationsBody: "仅在您授权后，Hub 才会为任务提醒发送本地通知。",
            .privacyThirdParty: "第三方服务",
            .privacyThirdPartyBody: "本应用不使用第三方广告或分析 SDK。",
            .categoryWork: "工作",
            .categoryDeepFocus: "深度专注",
            .categoryPersonal: "生活",
            .priorityLow: "低",
            .priorityMedium: "中",
            .priorityHigh: "高",
            .commonEdit: "编辑",
            .commonDelete: "删除",
            .commonTip: "提示",
            .commonOK: "好的",
            .todayEmptyNoTasks: "今天还没有任务",
            .todayEmptyNoResults: "未找到匹配任务",
            .todayInspiration: "保持专注，深呼吸。",
            .calendarPendingTasks: "%d 项待办任务",
            .calendarNoSchedule: "这一天暂无安排",
            .calendarAllDay: "全天",
            .calendarDaySelected: "已选日期",
            .priorityBadge: "%@优先",
            .priorityLevelSuffix: "%@优先级",
            .quickAddPlaceholder: "准备做什么？",
            .taskTitlePlaceholder: "任务标题",
            .editTaskTitle: "编辑任务",
            .setDate: "设置日期",
            .setReminder: "设置提醒",
            .dateLabel: "日期",
            .reminderTimeLabel: "提醒时间",
            .chooseCategory: "选择分类",
            .prioritySection: "优先级",
            .noDate: "无日期",
            .noPriority: "无优先级",
            .noReminder: "无提醒",
            .insightsTitle: "统计分析",
            .insightsProductivityScore: "生产力评分",
            .insightsBasedOnTasks: "基于 %d/%d 任务",
            .insightsCompletedTasks: "已完成任务",
            .insightsFocusDuration: "专注时长",
            .insightsCurrentStreak: "当前连续天数",
            .insightsStreakDaysUnit: "%d 天",
            .insightsFocusDistribution: "专注分布",
            .insightsKeepGoing: "继续保持！",
            .insightsStreakMessage: "你已连续专注 %d 天。建议在上午安排深度任务，保持节奏。",
            .insightsStartSmall: "完成更多任务可提升生产力评分。试试从一个小任务开始。",
            .focusHoursFormatted: "%d小时 %d分",
            .errorInvalidFormat: "无法识别的文件格式",
            .errorEmptyCSV: "CSV 文件为空",
            .errorInvalidCSVHeader: "CSV 表头不符合 Hub 导出格式",
            .alertImportedCSV: "已从 CSV 导入 %d 条任务",
            .errorICloudUnavailable: "未登录 iCloud 或 iCloud Drive 未开启",
            .errorEncodingFailed: "数据编码失败",
            .errorAvatarSaveFailed: "无法保存头像图片",
            .notifyTaskReminderTitle: "Hub 任务提醒",
            .faceSwitchToRahmi: "切换到 Rahmi",
            .faceSwitchToHub: "切换到 Hub",
            .demoUserName: "张伟",
            .sampleTaskDesign: "完成设计提案",
            .sampleTaskDeepWork: "深度工作：聚焦逻辑层",
            .sampleTaskShopping: "周末采购准备",
            .sampleTaskMeditation: "晨间冥想",
            .sampleTaskEmail: "批量处理邮件"
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
            .settingsStreakDays: "Focus streak",
            .settingsTitle: "Settings",
            .settingsAllTasks: "All tasks",
            .settingsCompleted: "Completed",
            .settingsStreakDayUnit: "%d days",
            .settingsProfile: "Profile",
            .settingsEdit: "Edit",
            .settingsPreferences: "Preferences",
            .settingsLanguage: "Language",
            .settingsTheme: "Appearance",
            .settingsFocusGoal: "Focus goal",
            .settingsFocusGoalHours: "%d hours",
            .settingsNotifications: "Notifications",
            .settingsNotificationsSubtitle: "Task reminders delivered on time",
            .settingsNotificationsDenied: "Notifications off — enable in Settings",
            .settingsOpenSystemSettings: "Open Settings",
            .settingsFocusSection: "Focus mode",
            .settingsFocusModeSettings: "Focus mode settings",
            .settingsFocusSummary: "%d min focus · %d min break",
            .settingsAboutFocus: "About focus mode",
            .settingsAboutFocusSubtitle: "Pomodoro tips & how-to",
            .settingsStartFocusNow: "Start focus now",
            .settingsDataSection: "Data & backup",
            .settingsCloudSync: "iCloud sync",
            .settingsDataManagement: "Data management",
            .settingsDataManagementSubtitle: "Export, import & iCloud",
            .settingsLastSync: "Last synced %@",
            .settingsAutoBackup: "Auto backup to iCloud",
            .settingsNotEnabled: "Off",
            .settingsAboutSection: "About",
            .settingsVersion: "Version",
            .settingsPrivacy: "Privacy policy",
            .settingsRateApp: "Rate app",
            .settingsRateAppSubtitle: "Your feedback helps us improve",
            .settingsHelp: "Help & support",
            .settingsResetDemo: "Reset demo data",
            .settingsResetTitle: "Reset all data?",
            .settingsResetMessage: "This clears your tasks and restores sample content. This cannot be undone.",
            .settingsResetDone: "Demo data restored",
            .settingsResetConfirmAction: "Reset",
            .commonCancel: "Cancel",
            .commonSave: "Save",
            .commonDone: "Done",
            .commonClose: "Close",
            .themeLight: "Light mode",
            .themeDark: "Dark mode",
            .themeSystem: "Match system",
            .themeLightSubtitle: "Always use light appearance",
            .themeDarkSubtitle: "Always use dark appearance",
            .themeSystemSubtitle: "Follow system appearance",
            .themePreview: "Preview",
            .themePreviewLight: "Light",
            .themePreviewDark: "Dark",
            .focusGoalHint: "Set a weekly focus target shown on the Insights tab.",
            .focusGoalPickerHours: "%d hours",
            .focusGoalSubtitleFormatted: "Goal: %dh",
            .profileEditTitle: "Edit profile",
            .profileBasicInfo: "Basic info",
            .profileName: "Name",
            .profileEmail: "Email",
            .profileRemoveAvatar: "Remove photo",
            .dataBackupSection: "Backup & restore",
            .dataExport: "Export data",
            .dataImport: "Import backup",
            .dataUploadCloud: "Upload to iCloud",
            .dataRestoreCloud: "Restore from iCloud",
            .dataCloudSyncToggle: "iCloud sync",
            .dataLastSyncInline: "Last synced: %@",
            .dataCloudFooter: "When enabled, tasks and settings are backed up to iCloud Drive.",
            .dataNavTitle: "Data & backup",
            .dataExportFormat: "Export format",
            .dataExportJSON: "JSON (with settings)",
            .dataExportCSV: "CSV (task list)",
            .dataRestoreTitle: "Restore from iCloud?",
            .dataRestoreAction: "Restore",
            .dataRestoreMessage: "This will overwrite local data with your iCloud backup. This cannot be undone.",
            .alertUploadedCloud: "Uploaded to iCloud",
            .alertNoCloudBackup: "No backup found in iCloud",
            .alertImportedTasks: "Imported %d tasks",
            .alertRestoredBackup: "Backup restored",
            .alertRestoredCloud: "Restored from iCloud",
            .alertProfileUpdated: "Profile updated",
            .alertNotificationDenied: "Allow Hub notifications in Settings",
            .alertExportFailed: "Export failed: %@",
            .alertSyncedCloud: "Synced to iCloud",
            .focusModeTitle: "Focus mode",
            .focusPomodoroSettings: "Pomodoro settings",
            .focusDuration: "Focus duration",
            .focusMinutesUnit: "%d min",
            .focusEnhanceSection: "Focus enhancements",
            .focusDeepMode: "Deep focus mode",
            .focusDeepModeSubtitle: "Blocks non-urgent notifications while enabled",
            .focusAmbientSection: "Ambient sounds",
            .focusSettingsEffectiveHint: "Settings apply the next time you start focus mode",
            .focusGuideReady: "Ready for your first pomodoro?",
            .focusGuideWhatIs: "What is the Pomodoro Technique?",
            .focusGuideIntro: "The Pomodoro Technique splits work into 25-minute focus blocks with 5-minute breaks, helping you stay focused without burning out.",
            .focusGuideHowTo: "How to use",
            .focusGuideStep1Title: "Pick a task",
            .focusGuideStep1Detail: "Choose one task from Today that needs deep focus.",
            .focusGuideStep2Title: "Start the timer",
            .focusGuideStep2Detail: "Run a 25-minute session and avoid distractions.",
            .focusGuideStep3Title: "Take a short break",
            .focusGuideStep3Detail: "When the timer ends, rest for 5 minutes — stretch and hydrate.",
            .focusGuideStep4Title: "Repeat the cycle",
            .focusGuideStep4Detail: "After 4 pomodoros, take a longer 15–30 minute break.",
            .focusGuideTips: "Focus tips",
            .focusGuideTip1: "Enable Do Not Disturb and place your phone face down.",
            .focusGuideTip2: "Have water ready before you start.",
            .focusGuideTip3: "Step away from screens during breaks and stretch lightly.",
            .ambientRain: "Rain",
            .ambientForest: "Forest",
            .ambientWhiteNoise: "White noise",
            .ambientCafe: "Café",
            .ambientRainSubtitle: "Gentle rain outside the window",
            .ambientForestSubtitle: "Morning birds and a light breeze",
            .ambientWhiteNoiseSubtitle: "Steady, comfortable background",
            .ambientCafeSubtitle: "Soft ambient café atmosphere",
            .privacyDataCollection: "Data collection",
            .privacyDataCollectionBody: "Hub stores tasks and preferences locally on your device. With iCloud sync enabled, data is encrypted in your iCloud account.",
            .privacyNotificationsSection: "Notifications",
            .privacyNotificationsBody: "Hub sends local task reminders only after you grant permission.",
            .privacyThirdParty: "Third-party services",
            .privacyThirdPartyBody: "This app does not use third-party ads or analytics SDKs.",
            .categoryWork: "Work",
            .categoryDeepFocus: "Deep focus",
            .categoryPersonal: "Personal",
            .priorityLow: "Low",
            .priorityMedium: "Medium",
            .priorityHigh: "High",
            .commonEdit: "Edit",
            .commonDelete: "Delete",
            .commonTip: "Notice",
            .commonOK: "OK",
            .todayEmptyNoTasks: "No tasks for today",
            .todayEmptyNoResults: "No matching tasks",
            .todayInspiration: "Stay focused. Breathe.",
            .calendarPendingTasks: "%d pending",
            .calendarNoSchedule: "Nothing scheduled",
            .calendarAllDay: "All day",
            .calendarDaySelected: "Selected",
            .priorityBadge: "%@ priority",
            .priorityLevelSuffix: "%@ priority",
            .quickAddPlaceholder: "What needs doing?",
            .taskTitlePlaceholder: "Task title",
            .editTaskTitle: "Edit task",
            .setDate: "Set date",
            .setReminder: "Set reminder",
            .dateLabel: "Date",
            .reminderTimeLabel: "Reminder time",
            .chooseCategory: "Choose category",
            .prioritySection: "Priority",
            .noDate: "No date",
            .noPriority: "No priority",
            .noReminder: "No reminder",
            .insightsTitle: "Insights",
            .insightsProductivityScore: "Productivity score",
            .insightsBasedOnTasks: "Based on %d/%d tasks",
            .insightsCompletedTasks: "Tasks completed",
            .insightsFocusDuration: "Focus time",
            .insightsCurrentStreak: "Current streak",
            .insightsStreakDaysUnit: "%d days",
            .insightsFocusDistribution: "Focus breakdown",
            .insightsKeepGoing: "Keep it up!",
            .insightsStreakMessage: "You've focused %d days in a row. Schedule deep work in the morning to keep momentum.",
            .insightsStartSmall: "Complete more tasks to raise your score. Start with something small.",
            .focusHoursFormatted: "%dh %dm",
            .errorInvalidFormat: "Unrecognized file format",
            .errorEmptyCSV: "CSV file is empty",
            .errorInvalidCSVHeader: "CSV header doesn't match Hub export format",
            .alertImportedCSV: "Imported %d tasks from CSV",
            .errorICloudUnavailable: "iCloud not signed in or iCloud Drive is off",
            .errorEncodingFailed: "Failed to encode data",
            .errorAvatarSaveFailed: "Couldn't save profile photo",
            .notifyTaskReminderTitle: "Hub task reminder",
            .faceSwitchToRahmi: "Switch to Rahmi",
            .faceSwitchToHub: "Switch to Hub",
            .demoUserName: "Alex Chen",
            .sampleTaskDesign: "Finish design proposal",
            .sampleTaskDeepWork: "Deep work: logic layer",
            .sampleTaskShopping: "Weekend shopping prep",
            .sampleTaskMeditation: "Morning meditation",
            .sampleTaskEmail: "Batch process email"
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
