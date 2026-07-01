//
//  VersionConfigStore.swift
//  Rahmi
//
//  A/B 面与支付策略由 `GET /v1/app_config` 控制（对齐 ReelMix GetAppConfigReq）。
//  - 已成功拉取并持久化：冷启动读本地，后台按间隔刷新。
//  - DEBUG：不请求 `app_config`，使用本地缓存或默认 type=1；可用首页调试条切换 type。
//  Hub 壳：`type == 2` → Web C 面；`type == 3` → Rahmi B 面；`type == 1` → Lumina A 面。Rahmi 内 A 面皮肤由 `suppressPresentationVariantAUI` 关闭。
//

import Foundation
import SwiftUI

@MainActor
final class VersionConfigStore: ObservableObject {
    /// Hub 集成下展示 Rahmi A 面皮肤（网格首页、A 充值页、直链 IAP）；设为 `true` 可回退为仅 B 面皮肤。
    static let suppressPresentationVariantAUI = false

    /// 与 `/v1/app_config` 的 `type` 一致：**1** 直链 IAP / Hub Lumina；**2** Hub Web C 面；**3** 支付 Sheet / Hub Rahmi。
    @Published private(set) var rechargePresentationType: Int
    /// C 面 H5 入口（由 app_config 或本地缓存解析）。
    @Published private(set) var surfaceWebURL: URL?
    /// 首启 app_config 完成前不切换根界面，避免闪 A 面。
    @Published private(set) var isBootstrapComplete = false

    static let persistedPresentationTypeKey = "rahmi.v1.app_config.presentation_type"
    static let persistedSurfaceWebURLKey = "rahmi.v1.app_config.surface_web_url"
    private static let persistedFetchSucceededKey = "rahmi.v1.app_config.fetch_succeeded"
    private static let lastRemoteRefreshKey = "rahmi.v1.app_config.last_remote_refresh"
    /// 旧版 `version_config` 键，仅用于迁移读取
    private static let legacyPresentationTypeKey = "rahmi.v1.version_config.presentation_type"

    private var bootstrapInFlight: Task<Void, Never>?
    private var remoteRefreshInFlight: Task<Void, Never>?

    #if DEBUG
    private var debugTypeOverrideActive = false
    #endif

    init() {
        if Self.hasPersistedSuccessfulFetch {
            let cached = Self.readStoredPresentationTypeNonisolated()
            _rechargePresentationType = Published(initialValue: cached)
            _surfaceWebURL = Published(initialValue: Self.resolvedSurfaceWebURL(forPresentationType: cached))
            _isBootstrapComplete = Published(initialValue: true)
        } else {
            _rechargePresentationType = Published(initialValue: 1)
            _surfaceWebURL = Published(initialValue: nil)
        }
    }

    /// Hub：`type == 3` → Rahmi B 面；`type == 2` → Web C 面；否则 → Lumina A 面
    var hubShowsRahmiFace: Bool { rechargePresentationType == 3 }

    var hubShowsWebFace: Bool { rechargePresentationType == 2 }

    var usesDirectIAPRecharge: Bool { rechargePresentationType == 1 }

    /// Rahmi 内 A 面皮肤；Hub 集成下恒为 `false`。
    var isPresentationVariantAUIEnabled: Bool {
        guard !Self.suppressPresentationVariantAUI else { return false }
        return rechargePresentationType == 1
    }

    nonisolated static func readPersistedPresentationType() -> Int {
        if UserDefaults.standard.bool(forKey: persistedFetchSucceededKey) {
            return readStoredPresentationTypeNonisolated()
        }
        return 1
    }

    nonisolated static func readPersistedSurfaceWebURL() -> String? {
        let raw = UserDefaults.standard.string(forKey: persistedSurfaceWebURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? nil : raw
    }

    nonisolated private static var hasPersistedSuccessfulFetch: Bool {
        UserDefaults.standard.bool(forKey: persistedFetchSucceededKey)
    }

    nonisolated private static func readStoredPresentationTypeNonisolated() -> Int {
        if let raw = UserDefaults.standard.object(forKey: persistedPresentationTypeKey) {
            if let n = raw as? Int, n == 1 || n == 2 || n == 3 { return n }
        }
        if let legacy = UserDefaults.standard.object(forKey: legacyPresentationTypeKey),
           let n = legacy as? Int, n == 1 || n == 2 || n == 3 {
            return n
        }
        return 1
    }

    nonisolated private static func resolvedSurfaceWebURL(forPresentationType type: Int) -> URL? {
        guard type == 2 else { return nil }
        return HubCFaceConfig.resolveURL(remoteURLString: readPersistedSurfaceWebURL())
    }

    private func persistSuccessfulPresentationType(_ value: Int, webURL: String? = nil) {
        guard value == 1 || value == 2 || value == 3 else { return }
        UserDefaults.standard.set(value, forKey: Self.persistedPresentationTypeKey)
        UserDefaults.standard.set(true, forKey: Self.persistedFetchSucceededKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyPresentationTypeKey)
        if let webURL {
            let trimmed = webURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                UserDefaults.standard.set(trimmed, forKey: Self.persistedSurfaceWebURLKey)
            }
        }
    }

    /// Release 隐蔽手势：返回 Hub A 面并持久化 type=1。
    func manualReturnToHubFace() {
        rechargePresentationType = 1
        surfaceWebURL = nil
        persistSuccessfulPresentationType(1)
    }

    func bootstrapOnColdStart() async {
        if Self.hasPersistedSuccessfulFetch {
            let cached = Self.readStoredPresentationTypeNonisolated()
            rechargePresentationType = cached
            surfaceWebURL = Self.resolvedSurfaceWebURL(forPresentationType: cached)
            isBootstrapComplete = true
            print("✅ [VersionConfigStore] app_config 使用本地缓存 type=\(cached)")
            Task(priority: .utility) { await self.refreshIfNeeded() }
            return
        }

        if let inFlight = bootstrapInFlight {
            await inFlight.value
            return
        }

        let task = Task { await self.performFirstLaunchBootstrap() }
        bootstrapInFlight = task
        await task.value
        bootstrapInFlight = nil
    }

    func refreshIfNeeded(minInterval: TimeInterval = 300, force: Bool = false) async {
        #if DEBUG
        return
        #else
        if !Self.hasPersistedSuccessfulFetch {
            await bootstrapOnColdStart()
            return
        }

        if !force {
            let last = UserDefaults.standard.double(forKey: Self.lastRemoteRefreshKey)
            guard last <= 0 || Date().timeIntervalSince1970 - last >= minInterval else { return }
        }

        if let inFlight = remoteRefreshInFlight {
            await inFlight.value
            return
        }

        let task = Task { await self.fetchAppConfigFromNetwork() }
        remoteRefreshInFlight = task
        await task.value
        remoteRefreshInFlight = nil
        #endif
    }

    func refresh() async {
        await refreshIfNeeded(force: true)
    }

    private func performFirstLaunchBootstrap() async {
        rechargePresentationType = 1
        surfaceWebURL = nil
        #if DEBUG
        print("ℹ️ [VersionConfigStore] DEBUG：跳过 app_config 首启请求，使用 type=\(rechargePresentationType)")
        isBootstrapComplete = true
        return
        #else
        print("📱 [VersionConfigStore] app_config 首启：默认 Hub(type=1)，等待 AF 后请求")

        /// 冷启动后略等网络路径就绪，减轻 Simulator 首包 TLS -1200
        try? await Task.sleep(nanoseconds: 500_000_000)

        let channel = await AppConfig.shared.getChannel()
        let (_, rawAttribution) = await RmThirdPartyAttributionBridge.shared.prepareForFirstLaunch(channelId: channel)

        var lastResult: Result<AppConfigResponse, AppError>?
        for attempt in 1 ... 3 {
            lastResult = await requestAppConfig(channel: channel, attribution: rawAttribution)
            if case .success = lastResult { break }
            if attempt < 3 {
                print("⚠️ [VersionConfigStore] app_config 首启第 \(attempt) 次失败，2s 后重试")
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        if let lastResult {
            await applyAppConfigResponse(lastResult)
        }
        isBootstrapComplete = true
        #endif
    }

    private func fetchAppConfigFromNetwork() async {
        let channel = await AppConfig.shared.getChannel()
        let rawAttribution = await RmThirdPartyAttributionBridge.shared.getAttributionForLogin()
        let result = await requestAppConfig(channel: channel, attribution: rawAttribution)
        if case .success = result {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastRemoteRefreshKey)
        }
        await applyAppConfigResponse(result)
    }

    private func requestAppConfig(
        channel: String,
        attribution raw: AFAttributionResult?
    ) async -> Result<AppConfigResponse, AppError> {
        let attribution = raw ?? AFAttributionResult.timeoutFallback()
        let deviceId = await DeviceManager.shared.getDeviceId()
        let version = await DeviceManager.shared.getAppVersion()
        let request = AppConfigRequest(
            devId: deviceId,
            source: attribution.source,
            channel: channel,
            version: version,
            afAttributionJson: attribution.attributionJson
        )
        return await RmAppConfigAPI.fetchAppConfig(request: request)
    }

    private func applyAppConfigResponse(_ result: Result<AppConfigResponse, AppError>) async {
        switch result {
        case .success(let resp):
            if let t = resp.type, t == 1 || t == 2 || t == 3 {
                #if DEBUG
                if debugTypeOverrideActive {
                    print("ℹ️ [VersionConfigStore] app_config type=\(t) ignored (DEBUG override, keep \(rechargePresentationType))")
                    return
                }
                #endif
                applyPresentation(t, webURLString: resp.preferredWebURLString)
                print("✅ [VersionConfigStore] app_config 成功 type=\(t)，已持久化")
            } else if !Self.hasPersistedSuccessfulFetch {
                applyFirstLaunchFailure(reason: "invalid_type")
            }
        case .failure(let error):
            if !Self.hasPersistedSuccessfulFetch {
                applyFirstLaunchFailure(reason: error.userMessage)
            } else {
                print("⚠️ [VersionConfigStore] app_config 刷新失败(\(error.userMessage))，保留 type=\(rechargePresentationType)")
            }
        }
    }

    private func applyPresentation(_ type: Int, webURLString: String?) {
        rechargePresentationType = type
        if type == 2 {
            surfaceWebURL = HubCFaceConfig.resolveURL(remoteURLString: webURLString)
            persistSuccessfulPresentationType(type, webURL: webURLString)
        } else {
            surfaceWebURL = nil
            persistSuccessfulPresentationType(type)
        }
    }

    private func applyFirstLaunchFailure(reason: String) {
        rechargePresentationType = 1
        surfaceWebURL = nil
        print("❌ [VersionConfigStore] app_config 首启失败(\(reason))，进 Hub(type=1) 且不保存")
    }

    #if DEBUG
    func debugSetPresentationType(_ raw: Int) {
        let v = (raw == 1 || raw == 2 || raw == 3) ? raw : 1
        debugTypeOverrideActive = true
        if v == 2 {
            applyPresentation(v, webURLString: Self.readPersistedSurfaceWebURL())
        } else {
            applyPresentation(v, webURLString: nil)
        }
        objectWillChange.send()
    }
    #endif
}
