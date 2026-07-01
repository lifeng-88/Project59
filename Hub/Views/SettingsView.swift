import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var faceController: AppFaceController
    @EnvironmentObject private var versionConfig: VersionConfigStore
    @Environment(\.hubLanguage) private var language

    @State private var showFocusGuide = false
    @State private var showFocusSettings = false
    @State private var showProfileEdit = false
    @State private var showThemeSheet = false
    @State private var showLanguageSheet = false
    @State private var showDataSheet = false
    @State private var showPrivacy = false
    @State private var showResetConfirm = false
    @State private var showFocusGoalSheet = false
    @State private var showAllTasksList = false
    @State private var showCompletedTasksList = false
    @State private var notificationDenied = false
    @State private var showDevIdCopiedToast = false
    /// 连续点击底部版本文案 10 次触发复制 dev_id；2s 内无继续点击则清零
    @State private var devIdFooterTapCount = 0
    @State private var devIdFooterTapResetTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HubTopBar(title: L10n.tr(.settingsTitle, language: language), showMenu: false, showSearch: false)

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
            .navigationDestination(isPresented: $showAllTasksList) {
                SettingsTasksListView(scope: .all)
            }
            .navigationDestination(isPresented: $showCompletedTasksList) {
                SettingsTasksListView(scope: .completed)
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
            .alert(L10n.tr(.settingsResetTitle, language: language), isPresented: $showResetConfirm) {
                Button(L10n.tr(.commonCancel, language: language), role: .cancel) {}
                Button(L10n.tr(.settingsResetConfirmAction, language: language), role: .destructive) {
                    store.resetAllData()
                    store.alertMessage = L10n.tr(.settingsResetDone, language: language)
                }
            } message: {
                Text(L10n.tr(.settingsResetMessage, language: language))
            }
            #endif
            .task {
                await checkNotificationStatus()
            }
            .onAppear { syncHubTabBarVisibility() }
            .onChange(of: showFocusGuide) { _, _ in syncHubTabBarVisibility() }
            .onChange(of: showFocusSettings) { _, _ in syncHubTabBarVisibility() }
            .onChange(of: showProfileEdit) { _, _ in syncHubTabBarVisibility() }
            .onChange(of: showAllTasksList) { _, _ in syncHubTabBarVisibility() }
            .onChange(of: showCompletedTasksList) { _, _ in syncHubTabBarVisibility() }
            .overlay(alignment: .top) {
                if showDevIdCopiedToast {
                    Text(devIdCopiedToastText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LuminaColor.onSurface)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(LuminaColor.surfaceContainerHigh)
                        .clipShape(Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private func syncHubTabBarVisibility() {
        store.hubTabBarHidden = showFocusGuide
            || showFocusSettings
            || showProfileEdit
            || showAllTasksList
            || showCompletedTasksList
    }

    // MARK: - 概览卡片

    private enum OverviewStatTarget {
        case allTasks
        case completed
        case streak
    }

    private var overviewCard: some View {
        HStack(spacing: 0) {
            overviewStatButton(
                value: "\(store.tasks.count)",
                label: L10n.tr(.settingsAllTasks, language: language),
                target: .allTasks
            )
            overviewDivider
            overviewStatButton(
                value: "\(store.completedCount)",
                label: L10n.tr(.settingsCompleted, language: language),
                target: .completed
            )
            overviewDivider
            overviewStatButton(
                value: streakValueLabel,
                label: L10n.tr(.settingsStreakDays, language: language),
                target: .streak
            )
        }
        .padding(.vertical, LuminaSpacing.stackMD)
        .background(LuminaColor.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        .luminaSoftShadow()
    }

    private func overviewStatButton(value: String, label: String, target: OverviewStatTarget) -> some View {
        Button {
            handleOverviewStatTap(target)
        } label: {
            overviewStat(value: value, label: label)
                .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRowButtonStyle())
    }

    private func handleOverviewStatTap(_ target: OverviewStatTarget) {
        switch target {
        case .allTasks:
            showAllTasksList = true
        case .completed:
            showCompletedTasksList = true
        case .streak:
            store.openInsightsFromSettingsOverview()
        }
    }

    private var streakValueLabel: String {
        let days = store.focusStreakDays
        if language == .en {
            return days == 1 ? "1 day" : "\(days) days"
        }
        return String(format: L10n.tr(.settingsStreakDayUnit, language: language), days)
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
            LuminaSectionLabel(title: L10n.tr(.settingsProfile, language: language))

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

                        Text(L10n.tr(.settingsEdit, language: language))
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
            LuminaSectionLabel(title: L10n.tr(.settingsPreferences, language: language))

            SettingsGroupCard {
                SettingsRowButton(
                    icon: "globe",
                    title: L10n.tr(.settingsLanguage, language: language),
                    trailing: store.appLanguage.displayName
                ) {
                    showLanguageSheet = true
                }

                SettingsDivider()

                SettingsRowButton(
                    icon: "moon.fill",
                    title: L10n.tr(.settingsTheme, language: language),
                    trailing: store.appTheme.displayName(language: language)
                ) {
                    showThemeSheet = true
                }

                SettingsDivider()

                SettingsRowButton(
                    icon: "target",
                    title: L10n.tr(.settingsFocusGoal, language: language),
                    trailing: String(
                        format: L10n.tr(.settingsFocusGoalHours, language: language),
                        store.focusGoalHours
                    )
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
            title: L10n.tr(.settingsNotifications, language: language),
            subtitle: notificationDenied
                ? L10n.tr(.settingsNotificationsDenied, language: language)
                : L10n.tr(.settingsNotificationsSubtitle, language: language),
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
                Button(L10n.tr(.settingsOpenSystemSettings, language: language)) {
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
            LuminaSectionLabel(title: L10n.tr(.settingsFocusSection, language: language))

            SettingsGroupCard {
                SettingsRowButton(
                    icon: "timer",
                    title: L10n.tr(.settingsFocusModeSettings, language: language),
                    subtitle: store.focusSettingsSummary(language: language),
                    iconColor: LuminaColor.tertiary
                ) {
                    showFocusSettings = true
                }

                SettingsDivider()

                SettingsRowButton(
                    icon: "info.circle",
                    title: L10n.tr(.settingsAboutFocus, language: language),
                    subtitle: L10n.tr(.settingsAboutFocusSubtitle, language: language),
                    iconColor: LuminaColor.tertiary,
                    showChevron: true
                ) {
                    showFocusGuide = true
                }

                SettingsDivider()

                SettingsRowButton(
                    icon: "bolt.fill",
                    title: L10n.tr(.settingsStartFocusNow, language: language),
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
            LuminaSectionLabel(title: L10n.tr(.settingsDataSection, language: language))

            SettingsGroupCard {
                SettingsToggleRow(
                    icon: "icloud.fill",
                    title: L10n.tr(.settingsCloudSync, language: language),
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
                    title: L10n.tr(.settingsDataManagement, language: language),
                    subtitle: L10n.tr(.settingsDataManagementSubtitle, language: language),
                    iconColor: LuminaColor.secondary
                ) {
                    showDataSheet = true
                }
            }
        }
    }

    private var syncSubtitle: String {
        if let date = store.lastCloudSyncDate {
            return String(
                format: L10n.tr(.settingsLastSync, language: language),
                date.formatted(date: .abbreviated, time: .shortened)
            )
        }
        return store.cloudSyncEnabled
            ? L10n.tr(.settingsAutoBackup, language: language)
            : L10n.tr(.settingsNotEnabled, language: language)
    }

    // MARK: - 关于

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
            LuminaSectionLabel(title: L10n.tr(.settingsAboutSection, language: language))

            SettingsGroupCard {
                if faceController.showsBFaceEntryOnHub {
                    SettingsRowButton(
                        icon: "sparkles",
                        title: L10n.tr(.faceSwitchToRahmi, language: language),
                        subtitle: L10n.tr(.settingsBFaceEntrySubtitle, language: language),
                        iconColor: LuminaColor.tertiary
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #if DEBUG
                        if AppFaceController.showsManualFaceSwitchInUI {
                            versionConfig.debugSetPresentationType(3)
                            faceController.applyPresentationType(3)
                        } else {
                            faceController.switchToRahmi()
                        }
                        #else
                        faceController.switchToRahmi()
                        #endif
                    }

                    SettingsDivider()
                }

                SettingsRowLabel(
                    icon: "info.circle",
                    title: L10n.tr(.settingsVersion, language: language),
                    trailing: AppInfo.versionLabel,
                    iconColor: LuminaColor.onSurfaceVariant,
                    showChevron: false
                )

                SettingsDivider()

                SettingsRowButton(
                    icon: "hand.raised.fill",
                    title: L10n.tr(.settingsPrivacy, language: language),
                    iconColor: LuminaColor.onSurfaceVariant,
                    trailingIcon: "arrow.up.right"
                ) {
                    showPrivacy = true
                }

                SettingsDivider()

                SettingsRowButton(
                    icon: "star.fill",
                    title: L10n.tr(.settingsRateApp, language: language),
                    subtitle: L10n.tr(.settingsRateAppSubtitle, language: language),
                    iconColor: LuminaColor.onSurfaceVariant
                ) {
                    AppReview.request()
                }

                SettingsDivider()

                SettingsRowButton(
                    icon: "questionmark.circle",
                    title: L10n.tr(.settingsHelp, language: language),
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
                        Text(L10n.tr(.settingsResetDemo, language: language))
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

            Button(action: handleDevIdFooterTap) {
                Text("Hub · Lumina Focus \(AppInfo.versionLabel)")
                    .font(.luminaLabelSM)
                    .foregroundStyle(LuminaColor.outline)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, LuminaSpacing.stackSM)
    }

    private var devIdCopiedToastText: String {
        language == .en ? "dev_id copied" : "dev_id 已复制"
    }

    private func handleDevIdFooterTap() {
        devIdFooterTapResetTask?.cancel()
        devIdFooterTapCount += 1

        if devIdFooterTapCount >= 10 {
            devIdFooterTapResetTask?.cancel()
            devIdFooterTapCount = 0
            copyDevIdToClipboard()
            return
        }

        devIdFooterTapResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            devIdFooterTapCount = 0
        }
    }

    private func copyDevIdToClipboard() {
        Task {
            let devId = await DeviceManager.shared.getDeviceId()
            await MainActor.run {
                UIPasteboard.general.string = devId
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { showDevIdCopiedToast = true }
            }
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                withAnimation { showDevIdCopiedToast = false }
            }
        }
    }

    private func checkNotificationStatus() async {
        let status = await NotificationService.authorizationStatus()
        notificationDenied = status == .denied
    }
}
