//
//  ContentView.swift
//  Rahmi
//
//  Created by MAC on 2026/03/31.
//

import SwiftUI
import UIKit

struct RahmiRootContentView: View {
    @EnvironmentObject private var auth: AuthSessionStore
    @EnvironmentObject private var versionConfig: VersionConfigStore
    @EnvironmentObject private var wallet: UserWalletStore
    @EnvironmentObject private var tabRouter: AppTabRouter
    @EnvironmentObject private var appLanguage: AppLanguageStore
    @Environment(\.scenePhase) private var scenePhase

    /// 首次登录成功后仅展示一次（含冷启动已恢复会话且尚未展示过的情况）
    @AppStorage("rahmi.welcomeBonusShown") private var welcomeBonusShown = false
    @State private var showWelcomeBonus = false

    /// 冷启动从锁屏点通知进入：`launchOptions.remoteNotification` 触发的路由可能早于 `auth.performLaunchAuthentication()`
    /// 完成；此时 `auth.isAuthenticated` 仍为 false 会被丢弃，缓存到此 State，待登录态变 true 后补放一次。
    @State private var pendingRemotePushRoute: RemotePushRoute?

    var body: some View {
        MainTabView()
            .preferredColorScheme(.dark)
            .onReceive(NotificationCenter.default.publisher(for: .rahmiAuthSessionDidUpdate)) { note in
                if let info = note.object as? AuthInfo {
                    auth.applySessionFromAuthInfo(info)
                }
            }
            .onAppear {
                BalanceManager.shared.bindWallet(wallet)
                // 与 `PushManager` 冷启动注册一致：不依赖「已登录」或横幅权限，尽早向 APNs 要 device token。
                UIApplication.shared.registerForRemoteNotifications()
            }
            .onReceive(NotificationCenter.default.publisher(for: .rahmiRemotePushRoute)) { note in
                guard let route = note.object as? RemotePushRoute else { return }
                Task { @MainActor in
                    if auth.isAuthenticated {
                        tabRouter.dispatchRemotePush(route)
                    } else {
                        // 冷启动 / 会话刚失效场景：登录态尚未恢复，先暂存，登录成功后由 `onChange` 补放。
                        print("📲 [ContentView] 收到推送路由但未登录，暂存等登录后再分发: \(route)")
                        pendingRemotePushRoute = route
                    }
                }
            }
            .onChange(of: auth.isAuthenticated) { isAuthed in
                if isAuthed {
                    UIApplication.shared.registerForRemoteNotifications()
                    evaluateWelcomeBonus()
                    if let pending = pendingRemotePushRoute {
                        pendingRemotePushRoute = nil
                        print("📲 [ContentView] 登录成功，补放暂存的推送路由: \(pending)")
                        tabRouter.dispatchRemotePush(pending)
                    }
                }
            }
            .overlay {
                if showWelcomeBonus {
                    WelcomeBonusOverlay(freeCoins: 2) {
                        welcomeBonusShown = true
                        showWelcomeBonus = false
                        tabRouter.select(.home)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(999)
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: showWelcomeBonus)
            .task {
                Task { await MediaCacheMaintenance.cleanExpiredCachesIfNeeded() }
                let channel = await AppConfig.shared.getChannel()
                if await RmThirdPartyAttributionBridge.shared.hasCompletedLoginBefore {
                    await RmThirdPartyAttributionBridge.shared.initAFAsync(channelId: channel)
                }
                await versionConfig.refresh()
                await auth.performLaunchAuthentication()
                // 会话恢复后再登记一次，避免 onAppear 早于 `isAuthenticated` 为 true 时漏调。
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                await PushRechargeOrderAttributionStore.shared.loadPersistedIfNeeded()
                RmStoreKitPurchaseOrchestrator.shared.startListening()
                evaluateWelcomeBonus()
            }
            .rahmiRefreshOnAppLanguage()
            .onChange(of: appLanguage.preference) { _ in
                guard auth.isAuthenticated else { return }
                Task.detached(priority: .utility) {
                    await UserLocaleReporter.reportIfAuthenticated(reason: "language_changed")
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    appLanguage.refreshUITextForPossibleSystemLocaleChange()
                } else if phase == .background {
                    Task { await RmClientTelemetryOutbox.shared.flush() }
                }
            }
    }

    private func evaluateWelcomeBonus() {
        guard auth.isAuthenticated, !welcomeBonusShown else { return }
        showWelcomeBonus = true
    }
}

#Preview {
    RahmiRootContentView()
        .environmentObject(UserWalletStore())
        .environmentObject(AppTabRouter())
        .environmentObject(AuthSessionStore())
        .environmentObject(VersionConfigStore())
        .environmentObject(AppLanguageStore())
        .environment(\.locale, Locale.current)
}
