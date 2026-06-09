import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: TaskStore

    @State private var showFocusGuide = false
    @State private var showFocusSettings = false
    @State private var showProfileEdit = false
    @State private var showThemeSheet = false
    @State private var showLanguageSheet = false
    @State private var showDataSheet = false
    @State private var showPrivacy = false
    @State private var showResetConfirm = false
    @State private var showFocusGoalSheet = false
    @State private var notificationDenied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HubTopBar(title: "设置", showMenu: false, showSearch: false)

                    VStack(alignment: .leading, spacing: LuminaSpacing.stackXL) {
                        overviewCard
                        profileSection
                        preferencesSection
                        focusSection
                        dataSection
                        aboutSection
                        dangerZone
                    }
                    .padding(.horizontal, LuminaSpacing.marginPage)
                    .padding(.top, LuminaSpacing.stackMD)
                    .padding(.bottom, LuminaSpacing.stackXL)
                }
            }
            .background(LuminaColor.surface)
            .refreshable {
                await store.refreshFromCloudAndNotifications()
                await checkNotificationStatus()
            }
            .navigationDestination(isPresented: $showFocusGuide) {
                FocusModeGuideView()
            }
            .navigationDestination(isPresented: $showFocusSettings) {
                FocusModeSettingsView()
            }
            .navigationDestination(isPresented: $showProfileEdit) {
                ProfileEditView()
            }
            .sheet(isPresented: $showThemeSheet) {
                ThemePickerSheet()
            }
            .sheet(isPresented: $showLanguageSheet) {
                LanguagePickerSheet()
            }
            .sheet(isPresented: $showDataSheet) {
                DataManagementSheet()
            }
            .sheet(isPresented: $showPrivacy) {
                LuminaPrivacyPolicyView()
            }
            .sheet(isPresented: $showFocusGoalSheet) {
                FocusGoalSheet()
            }
            #if DEBUG
            .alert("重置所有数据？", isPresented: $showResetConfirm) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) {
                    store.resetAllData()
                    store.alertMessage = "已恢复为演示数据"
                }
            } message: {
                Text("将清除当前任务并恢复示例内容，此操作不可撤销。")
            }
            #endif
            .task {
                await checkNotificationStatus()
            }
        }
    }

    // MARK: - 概览卡片

    private var overviewCard: some View {
        HStack(spacing: 0) {
            overviewStat(value: "\(store.tasks.count)", label: "全部任务")
            overviewDivider
            overviewStat(value: "\(store.completedCount)", label: "已完成")
            overviewDivider
            overviewStat(
                value: streakValueLabel,
                label: L10n.tr(.settingsStreakDays, language: store.appLanguage)
            )
        }
        .padding(.vertical, LuminaSpacing.stackMD)
        .background(LuminaColor.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        .luminaSoftShadow()
    }

    private var streakValueLabel: String {
        let days = store.focusStreakDays
        if store.appLanguage == .en {
            return days == 1 ? "1 day" : "\(days) days"
        }
        return "\(days)天"
    }

    private var overviewDivider: some View {
        Rectangle()
            .fill(LuminaColor.surfaceVariant.opacity(0.5))
            .frame(width: 1, height: 36)
    }

    private func overviewStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.luminaHeadlineMobile)
                .foregroundStyle(LuminaColor.primary)
            Text(label)
                .font(.luminaLabelSM)
                .foregroundStyle(LuminaColor.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 个人资料

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
            LuminaSectionLabel(title: "个人资料")

            SettingsGroupCard {
                Button { showProfileEdit = true } label: {
                    HStack(spacing: LuminaSpacing.stackMD) {
                        ProfileAvatarView(
                            image: store.profileAvatarImage,
                            initials: store.userInitials,
                            size: 52
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.userName)
                                .font(.luminaBodyLG)
                                .foregroundStyle(LuminaColor.onSurface)
                            Text(store.userEmail)
                                .font(.luminaLabelMD)
                                .foregroundStyle(LuminaColor.onSurfaceVariant)
                        }

                        Spacer()

                        Text("编辑")
                            .font(.luminaLabelMD)
                            .foregroundStyle(LuminaColor.onSurfaceVariant)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(LuminaColor.outlineVariant)
                    }
                    .padding(LuminaSpacing.insetMD)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SettingsRowButtonStyle())
            }
        }
    }

    // MARK: - 偏好

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
            LuminaSectionLabel(title: "偏好设置")

            SettingsGroupCard {
                SettingsRowButton(
                    icon: "globe",
                    title: "语言",
                    trailing: store.appLanguage.displayName
                ) {
                    showLanguageSheet = true
                }

                SettingsDivider()

                SettingsRowButton(
                    icon: "moon.fill",
                    title: "主题模式",
                    trailing: store.appTheme.displayName
                ) {
                    showThemeSheet = true
                }

                SettingsDivider()

                SettingsRowButton(
                    icon: "target",
                    title: "专注目标",
                    trailing: "\(store.focusGoalHours) 小时"
                ) {
                    showFocusGoalSheet = true
                }

                SettingsDivider()

                notificationRow
            }
        }
    }

    private var notificationRow: some View {
        SettingsToggleRow(
            icon: "bell.fill",
            title: "提醒通知",
            subtitle: notificationDenied ? "通知已关闭，请在系统设置中开启" : "任务提醒将准时推送",
            isOn: Binding(
                get: { store.notificationsEnabled },
                set: { newValue in
                    Task {
                        await store.setNotificationsEnabled(newValue)
                        await checkNotificationStatus()
                    }
                }
            )
        ) {
            if notificationDenied {
                Button("前往系统设置") {
                    store.openSystemNotificationSettings()
                }
                .font(.luminaLabelMD)
                .foregroundStyle(LuminaColor.primary)
                .padding(.leading, 40)
            }
        }
    }

    // MARK: - 专注

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
            LuminaSectionLabel(title: "专注模式")

            SettingsGroupCard {
                SettingsRowButton(
                    icon: "timer",
                    title: "专注模式设置",
                    subtitle: store.focusSettingsSummary,
                    iconColor: LuminaColor.tertiary
                ) {
                    showFocusSettings = true
                }

                SettingsDivider()

                SettingsRowButton(
                    icon: "info.circle",
                    title: "关于专注模式",
                    subtitle: "番茄工作法与使用技巧",
                    iconColor: LuminaColor.tertiary,
                    showChevron: true
                ) {
                    showFocusGuide = true
                }

                SettingsDivider()

                SettingsRowButton(
                    icon: "bolt.fill",
                    title: "立即开始专注",
                    iconColor: LuminaColor.primary,
                    showChevron: false,
                    trailingIcon: "play.circle.fill"
                ) {
                    store.startFocusSession()
                }
            }
        }
    }

    // MARK: - 数据

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
            LuminaSectionLabel(title: "数据与备份")

            SettingsGroupCard {
                SettingsToggleRow(
                    icon: "icloud.fill",
                    title: "云端同步",
                    subtitle: syncSubtitle,
                    isOn: Binding(
                        get: { store.cloudSyncEnabled },
                        set: { store.setCloudSyncEnabled($0) }
                    ),
                    iconColor: LuminaColor.secondary
                )

                SettingsDivider()

                SettingsRowButton(
                    icon: "externaldrive.fill",
                    title: "数据管理",
                    subtitle: "导出、导入与 iCloud",
                    iconColor: LuminaColor.secondary
                ) {
                    showDataSheet = true
                }
            }
        }
    }

    private var syncSubtitle: String {
        if let date = store.lastCloudSyncDate {
            return "上次同步 \(date.formatted(date: .abbreviated, time: .shortened))"
        }
        return store.cloudSyncEnabled ? "自动备份到 iCloud" : "未开启"
    }

    // MARK: - 关于

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
            LuminaSectionLabel(title: "关于应用")

            SettingsGroupCard {
                SettingsRowLabel(
                    icon: "info.circle",
                    title: "版本号",
                    trailing: AppInfo.versionLabel,
                    iconColor: LuminaColor.onSurfaceVariant,
                    showChevron: false
                )

                SettingsDivider()

                SettingsRowButton(
                    icon: "hand.raised.fill",
                    title: "隐私政策",
                    iconColor: LuminaColor.onSurfaceVariant,
                    trailingIcon: "arrow.up.right"
                ) {
                    showPrivacy = true
                }

                SettingsDivider()

                SettingsRowButton(
                    icon: "star.fill",
                    title: "评价应用",
                    subtitle: "您的反馈帮助我们改进",
                    iconColor: LuminaColor.onSurfaceVariant
                ) {
                    AppReview.request()
                }

                SettingsDivider()

                SettingsRowButton(
                    icon: "questionmark.circle",
                    title: "帮助与支持",
                    iconColor: LuminaColor.onSurfaceVariant
                ) {
                    showFocusGuide = true
                }
            }
        }
    }

    // MARK: - 危险操作

    private var dangerZone: some View {
        VStack(spacing: LuminaSpacing.stackMD) {
            if HubDemoData.isEnabled {
                Button {
                    showResetConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重置演示数据")
                    }
                    .font(.luminaBodyMD)
                    .foregroundStyle(LuminaColor.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LuminaColor.errorContainer.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
                }
                .buttonStyle(.plain)
            }

            Text("Hub · Lumina Focus \(AppInfo.versionLabel)")
                .font(.luminaLabelSM)
                .foregroundStyle(LuminaColor.outline)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, LuminaSpacing.stackSM)
    }

    private func checkNotificationStatus() async {
        let status = await NotificationService.authorizationStatus()
        notificationDenied = status == .denied
    }
}
