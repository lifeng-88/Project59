import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class TaskStore: ObservableObject {
    @Published var tasks: [HubTask] = []
    @Published var selectedTab: HubTab = .today
    /// 当前 Tab 内进入二级导航时隐藏底部 HubBottomBar（与 Rahmi `shouldHideTabBar` 行为一致）
    @Published var hubTabBarHidden = false
    @Published var showQuickAdd = false
    @Published var showFocusTimer = false
    @Published var showSideMenu = false
    @Published var taskToEdit: HubTask?
    @Published var exportFile: ExportFile?
    @Published var alertMessage: String?
    @Published var lastCloudSyncDate: Date?
    @Published var calendarSelectedDate = Date()
    @Published var quickAddPrefillDate: Date?
    @Published var userName = HubDemoData.isEnabled
        ? L10n.tr(.demoUserName, language: AppLanguage.defaultFromSystem()) : ""
    @Published var userEmail = HubDemoData.isEnabled
        ? TaskStore.demoUserEmail(for: AppLanguage.defaultFromSystem()) : ""
    @Published var profileAvatarImage: UIImage?
    @Published var notificationsEnabled = true
    @Published var pomodoroMinutes = 25
    @Published var breakMinutes = 5
    @Published var longBreakMinutes = 15
    @Published var deepFocusEnabled = true
    @Published var selectedAmbientSound: AmbientSound? = .rain
    @Published var cloudSyncEnabled = true
    @Published var appTheme: HubAppearanceTheme = .light
    @Published var appLanguage: AppLanguage = AppLanguage.defaultFromSystem()
    @Published var focusStreakDays = 0
    @Published var lastFocusActivityDate: Date?
    @Published var totalFocusMinutes = 0
    @Published var focusGoalMinutes = 1200

    var colorScheme: ColorScheme? {
        switch appTheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var activeTasks: [HubTask] {
        tasks.filter { !$0.isCompleted }
    }

    var completedTasks: [HubTask] {
        tasks.filter(\.isCompleted)
    }

    var remainingCount: Int {
        tasksForToday.filter { !$0.isCompleted }.count
    }

    var completedCount: Int {
        tasks.filter(\.isCompleted).count
    }

    var productivityScore: Int {
        guard !tasks.isEmpty else { return 0 }
        let rate = Double(completedCount) / Double(tasks.count)
        return min(100, max(0, Int(rate * 100)))
    }

    var tasksForToday: [HubTask] {
        tasks.filter { task in
            guard let date = task.scheduledDate else { return true }
            return Calendar.current.isDateInToday(date)
        }
    }

    init() {
        if let saved = AppPersistence.load() {
            apply(saved)
            if !HubDemoData.isEnabled, Self.isSampleTaskSet(tasks) {
                tasks = []
                persist()
            }
        } else {
            appLanguage = AppLanguage.defaultFromSystem()
            tasks = HubDemoData.isEnabled ? Self.sampleTasks(language: appLanguage) : []
            if HubDemoData.isEnabled {
                userName = L10n.tr(.demoUserName, language: appLanguage)
                userEmail = Self.demoUserEmail(for: appLanguage)
            }
            persist()
        }
        if syncDemoSampleContentIfNeeded() {
            persist()
        }
        lastCloudSyncDate = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
        profileAvatarImage = ProfileImageStore.load()
    }

    private static let lastSyncKey = "hub.lastCloudSync"

    private func apply(_ saved: PersistedAppState) {
        tasks = saved.tasks
        notificationsEnabled = saved.notificationsEnabled
        pomodoroMinutes = saved.pomodoroMinutes
        breakMinutes = saved.breakMinutes
        longBreakMinutes = saved.longBreakMinutes
        deepFocusEnabled = saved.deepFocusEnabled
        selectedAmbientSound = saved.selectedAmbientSound
        cloudSyncEnabled = saved.cloudSyncEnabled
        appTheme = saved.appTheme
        focusStreakDays = saved.focusStreakDays
        lastFocusActivityDate = saved.lastFocusActivityDate
        totalFocusMinutes = saved.totalFocusMinutes
        focusGoalMinutes = saved.focusGoalMinutes ?? 1200
        appLanguage = saved.appLanguage ?? AppLanguage.defaultFromSystem()
        userName = saved.userName ?? (HubDemoData.isEnabled ? L10n.tr(.demoUserName, language: appLanguage) : "")
        userEmail = saved.userEmail ?? (HubDemoData.isEnabled ? Self.demoUserEmail(for: appLanguage) : "")
    }

    /// DEBUG 演示数据：语言与当前 `appLanguage` 不一致时刷新示例任务与演示资料。
    @discardableResult
    func syncDemoSampleContentIfNeeded() -> Bool {
        guard HubDemoData.isEnabled else { return false }
        var changed = false

        if Self.isSampleTaskSet(tasks) {
            let localized = Self.sampleTasks(language: appLanguage)
            let titlesDiffer = zip(tasks, localized).contains { $0.title != $1.title }
            if titlesDiffer {
                tasks = zip(tasks, localized).map { old, new in
                    var task = new
                    task.isCompleted = old.isCompleted
                    task.completedAt = old.isCompleted ? old.completedAt : nil
                    return task
                }
                changed = true
            }
        }

        let demoName = L10n.tr(.demoUserName, language: appLanguage)
        if Self.allDemoUserNames().contains(userName), userName != demoName {
            userName = demoName
            changed = true
        }

        let demoEmail = Self.demoUserEmail(for: appLanguage)
        if Self.demoUserEmails.contains(userEmail), userEmail != demoEmail {
            userEmail = demoEmail
            changed = true
        }

        return changed
    }

    func focusSettingsSummary(language: AppLanguage) -> String {
        String(
            format: L10n.tr(.settingsFocusSummary, language: language),
            pomodoroMinutes,
            breakMinutes
        )
    }

    var focusSettingsSummary: String {
        focusSettingsSummary(language: appLanguage)
    }

    var userInitials: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "H" }
        return String(first).uppercased()
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func resetAllData() {
        guard HubDemoData.isEnabled else { return }
        tasks = Self.sampleTasks(language: appLanguage)
        focusStreakDays = 0
        lastFocusActivityDate = nil
        totalFocusMinutes = 0
        focusGoalMinutes = 1200
        profileAvatarImage = nil
        ProfileImageStore.delete()
        FocusSessionStore.save(nil)
        NotificationService.cancelFocusPhaseEnd()
        persist()
        Task { await syncNotifications() }
    }

    func tasks(on date: Date) -> [HubTask] {
        tasks.filter { task in
            guard let scheduled = task.scheduledDate else { return false }
            return Calendar.current.isDate(scheduled, inSameDayAs: date)
        }
        .sorted { ($0.reminderDate ?? $0.scheduledDate ?? .distantPast) < ($1.reminderDate ?? $1.scheduledDate ?? .distantPast) }
    }

    func hasTasks(on date: Date) -> Bool {
        !tasks(on: date).isEmpty
    }

    func categoryDistribution() -> [(TaskCategory, Double)] {
        let categorized = tasks.compactMap(\.category)
        guard !categorized.isEmpty else {
            return TaskCategory.allCases.map { ($0, 1.0 / Double(TaskCategory.allCases.count)) }
        }
        let total = Double(categorized.count)
        return TaskCategory.allCases.map { category in
            let count = Double(categorized.filter { $0 == category }.count)
            return (category, count / total)
        }
    }

    func toggle(_ task: HubTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted.toggle()
        if tasks[index].isCompleted {
            tasks[index].completedAt = Date()
            NotificationService.cancelReminder(for: tasks[index])
            if tasks[index].category == .deepFocus {
                totalFocusMinutes += pomodoroMinutes
            }
        } else {
            tasks[index].completedAt = nil
        }
        persist()
        if !tasks[index].isCompleted {
            Task { await refreshNotifications(for: tasks[index], isNew: false) }
        }
    }

    func addTask(
        title: String,
        category: TaskCategory? = nil,
        scheduledDate: Date? = nil,
        priority: HubTaskPriority? = nil,
        reminderDate: Date? = nil
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let due = scheduledDate.map { Calendar.current.startOfDay(for: $0) }
        let task = HubTask(
            title: trimmed,
            category: category,
            scheduledDate: due,
            priority: priority,
            reminderDate: reminderDate
        )
        tasks.insert(task, at: 0)
        persist()
        Task { await refreshNotifications(for: task, isNew: true) }
    }

    func updateTask(
        _ task: HubTask,
        title: String,
        category: TaskCategory?,
        scheduledDate: Date?,
        priority: HubTaskPriority?,
        reminderDate: Date?
    ) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        NotificationService.cancelReminder(for: tasks[index])
        tasks[index].title = trimmed
        tasks[index].category = category
        tasks[index].scheduledDate = scheduledDate.map { Calendar.current.startOfDay(for: $0) }
        tasks[index].priority = priority
        tasks[index].reminderDate = reminderDate
        persist()
        Task { await refreshNotifications(for: tasks[index], isNew: false) }
    }

    func deleteTask(_ task: HubTask) {
        NotificationService.cancelReminder(for: task)
        tasks.removeAll { $0.id == task.id }
        persist()
        Task { await syncNotifications() }
    }

    var persistedState: PersistedAppState {
        PersistedAppState(
            tasks: tasks,
            notificationsEnabled: notificationsEnabled,
            pomodoroMinutes: pomodoroMinutes,
            breakMinutes: breakMinutes,
            longBreakMinutes: longBreakMinutes,
            deepFocusEnabled: deepFocusEnabled,
            selectedAmbientSound: selectedAmbientSound,
            cloudSyncEnabled: cloudSyncEnabled,
            appTheme: appTheme,
            focusStreakDays: focusStreakDays,
            lastFocusActivityDate: lastFocusActivityDate,
            totalFocusMinutes: totalFocusMinutes,
            focusGoalMinutes: focusGoalMinutes,
            hasLoadedSampleData: HubDemoData.isEnabled && Self.isSampleTaskSet(tasks),
            userName: userName,
            userEmail: userEmail,
            appLanguage: appLanguage
        )
    }

    func updateProfile(name: String, email: String, avatar: UIImage?, removeAvatar: Bool = false) {
        userName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        userEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        if removeAvatar {
            ProfileImageStore.delete()
            profileAvatarImage = nil
        } else if let avatar {
            try? ProfileImageStore.save(avatar)
            profileAvatarImage = avatar
        }

        persist()
        alertMessage = L10n.tr(.alertProfileUpdated, language: appLanguage)
    }

    var focusGoalHours: Int {
        max(1, focusGoalMinutes / 60)
    }

    var focusGoalProgress: Double {
        guard focusGoalMinutes > 0 else { return 0 }
        return min(1, Double(totalFocusMinutes) / Double(focusGoalMinutes))
    }

    var focusGoalSubtitle: String {
        String(format: L10n.tr(.focusGoalSubtitleFormatted, language: appLanguage), focusGoalHours)
    }

    func setFocusGoalHours(_ hours: Int) {
        focusGoalMinutes = max(60, min(6000, hours * 60))
        persist()
    }

    func prepareQuickAdd(for date: Date?) {
        quickAddPrefillDate = date.map { Calendar.current.startOfDay(for: $0) }
    }

    func clearQuickAddPrefill() {
        quickAddPrefillDate = nil
    }

    func weeklyChartNormalizedValues() -> [CGFloat] {
        let counts = weeklyCompletionCounts()
        let max = CGFloat(counts.max() ?? 1)
        guard max > 0 else { return Array(repeating: 0.2, count: 7) }
        return counts.map { CGFloat($0) / max }
    }

    func weeklyCompletionCounts() -> [Int] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).map { offset in
            guard let day = cal.date(byAdding: .day, value: -6 + offset, to: today) else { return 0 }
            return tasks.filter { task in
                guard task.isCompleted else { return false }
                let ref = task.completedAt ?? task.scheduledDate ?? task.createdAt
                return cal.isDate(ref, inSameDayAs: day)
            }.count
        }
    }

    func applyImportedState(_ payload: DataExportService.ExportPayload) {
        tasks = payload.tasks
        apply(payload.settings)
        persist()
        Task { await syncNotifications() }
        alertMessage = String(format: L10n.tr(.alertImportedTasks, language: appLanguage), payload.tasks.count)
    }

    func applyImportedState(_ state: PersistedAppState) {
        apply(state)
        persist()
        Task { await syncNotifications() }
        alertMessage = L10n.tr(.alertRestoredBackup, language: appLanguage)
    }

    func restoreFromCloud() {
        do {
            guard let backup = try CloudSyncService.loadBackup() else {
                alertMessage = L10n.tr(.alertNoCloudBackup, language: appLanguage)
                return
            }
            apply(backup)
            persist()
            lastCloudSyncDate = Date()
            UserDefaults.standard.set(lastCloudSyncDate, forKey: Self.lastSyncKey)
            Task { await syncNotifications() }
            alertMessage = L10n.tr(.alertRestoredCloud, language: appLanguage)
        } catch {
            alertMessage = L10n.hubErrorMessage(error, language: appLanguage)
        }
    }

    @MainActor
    func refreshFromCloudAndNotifications() async {
        await syncNotifications()
        if cloudSyncEnabled {
            do {
                try performCloudSync()
            } catch {
                alertMessage = L10n.hubErrorMessage(error, language: appLanguage)
            }
        }
    }

    func setupOnLaunch() async {
        if notificationsEnabled {
            let granted = await NotificationService.requestAuthorization()
            if !granted { notificationsEnabled = false; persist() }
        }
        await syncNotifications()
        if cloudSyncEnabled {
            try? performCloudSync()
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        if enabled {
            let granted = await NotificationService.requestAuthorization()
            notificationsEnabled = granted
            if !granted {
                alertMessage = L10n.tr(.alertNotificationDenied, language: appLanguage)
            }
        } else {
            notificationsEnabled = false
        }
        persist()
        await syncNotifications()
    }

    func syncNotifications() async {
        await NotificationService.syncAll(tasks: tasks, enabled: notificationsEnabled, language: appLanguage)
    }

    private func refreshNotifications(for task: HubTask, isNew: Bool) async {
        NotificationService.cancelReminder(for: task)
        guard notificationsEnabled, !task.isCompleted else { return }
        NotificationService.scheduleReminder(for: task, language: appLanguage)
    }

    func exportData(format: ExportFormat) {
        do {
            let data: Data
            switch format {
            case .json:
                data = try DataExportService.makeJSONData(store: self)
            case .csv:
                data = DataExportService.makeCSVData(store: self)
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(format.fileName)
            try data.write(to: url, options: .atomic)
            exportFile = ExportFile(url: url)
        } catch {
            alertMessage = String(format: L10n.tr(.alertExportFailed, language: appLanguage), error.localizedDescription)
        }
    }

    func performCloudSync() throws {
        let date = try CloudSyncService.sync(state: persistedState)
        lastCloudSyncDate = date
        UserDefaults.standard.set(date, forKey: Self.lastSyncKey)
    }

    func setCloudSyncEnabled(_ enabled: Bool) {
        cloudSyncEnabled = enabled
        persist()
        if enabled {
            do {
                try performCloudSync()
                alertMessage = L10n.tr(.alertSyncedCloud, language: appLanguage)
            } catch {
                cloudSyncEnabled = false
                persist()
                alertMessage = L10n.hubErrorMessage(error, language: appLanguage)
            }
        }
    }

    func filteredTasks(search: String, todayOnly: Bool) -> [HubTask] {
        var list = todayOnly ? tasksForToday : tasks
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            list = list.filter { $0.title.localizedCaseInsensitiveContains(query) }
        }
        return list.sorted { !$0.isCompleted && $1.isCompleted }
    }

    func startFocusSession() {
        showFocusTimer = true
    }

    func openInsightsFromSettingsOverview() {
        selectedTab = .insights
    }

    func completeFocusSession() {
        totalFocusMinutes += pomodoroMinutes
        let result = FocusStreakCalculator.updatedStreak(
            currentStreak: focusStreakDays,
            lastActivityDate: lastFocusActivityDate
        )
        focusStreakDays = result.streak
        lastFocusActivityDate = result.lastActivityDate
        persist()
    }

    func clearActiveFocusSession() {
        FocusSessionStore.save(nil)
        NotificationService.cancelFocusPhaseEnd()
    }

    func persist() {
        AppPersistence.save(persistedState)
        if cloudSyncEnabled {
            try? performCloudSync()
        }
    }

    static func sampleTasks(language: AppLanguage) -> [HubTask] {
        [
            HubTask(title: L10n.tr(.sampleTaskDesign, language: language), category: .work, scheduledDate: Date()),
            HubTask(title: L10n.tr(.sampleTaskDeepWork, language: language), category: .deepFocus, scheduledDate: Date()),
            HubTask(title: L10n.tr(.sampleTaskShopping, language: language), scheduledDate: Date()),
            HubTask(title: L10n.tr(.sampleTaskMeditation, language: language), isCompleted: true, scheduledDate: Date()),
            HubTask(title: L10n.tr(.sampleTaskEmail, language: language), category: .work, isCompleted: true, scheduledDate: Date())
        ]
    }

    static let sampleTasks: [HubTask] = sampleTasks(language: AppLanguage.defaultFromSystem())

    static func demoUserEmail(for language: AppLanguage) -> String {
        language == .en ? "alex.chen@lumina.io" : "zhangwei@lumina.io"
    }

    private static let demoUserEmails: Set<String> = ["zhangwei@lumina.io", "alex.chen@lumina.io"]

    private static func allDemoUserNames() -> Set<String> {
        Set(AppLanguage.allCases.map { L10n.tr(.demoUserName, language: $0) })
    }

    private static func isSampleTaskSet(_ tasks: [HubTask]) -> Bool {
        guard tasks.count == sampleTasks.count else { return false }
        let allSampleTitles = Set(AppLanguage.allCases.flatMap { sampleTasks(language: $0).map(\.title) })
        return Set(tasks.map(\.title)).isSubset(of: allSampleTitles)
    }

    var focusHoursFormatted: String {
        let hours = totalFocusMinutes / 60
        let mins = totalFocusMinutes % 60
        return String(format: L10n.tr(.focusHoursFormatted, language: appLanguage), hours, mins)
    }
}

enum HubTab: String, CaseIterable {
    case today
    case calendar
    case insights
    case settings

    var icon: String {
        switch self {
        case .today: return "calendar"
        case .calendar: return "calendar.badge.clock"
        case .insights: return "chart.xyaxis.line"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .today: return "calendar.circle.fill"
        case .calendar: return "calendar.badge.clock"
        case .insights: return "chart.xyaxis.line"
        case .settings: return "gearshape.fill"
        }
    }

    var showsFAB: Bool {
        switch self {
        case .today, .calendar: return true
        case .insights, .settings: return false
        }
    }
}
