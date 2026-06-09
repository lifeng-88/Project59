//
//  VersionConfigStore.swift
//  Rahmi
//
//  A/B 面与支付策略由 `GET /v1/app_config` 控制（对齐 ReelMix GetAppConfigReq）。
//  - 已成功拉取并持久化：冷启动读本地，后台按间隔刷新。
//  - 首次 / 从未成功：先 AF 归因，再请求 app_config；失败则 type=1（Hub）且不写入本地。
//  Hub 壳：`type == 2` → Rahmi；`type == 1` → Lumina。Rahmi 内 A 面皮肤由 `suppressPresentationVariantAUI` 关闭。
//

import Foundation
import SwiftUI

@MainActor
final class VersionConfigStore: ObservableObject {
    static let suppressPresentationVariantAUI = true

    /// 与 `/v1/app_config` 的 `type` 一致：**1** 直链 IAP；**2** 支付 Sheet。
    @Published private(set) var rechargePresentationType: Int

    static let persistedPresentationTypeKey = "rahmi.v1.app_config.presentation_type"
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
            _rechargePresentationType = Published(initialValue: Self.readStoredPresentationTypeNonisolated())
        } else {
            _rechargePresentationType = Published(initialValue: 1)
        }
    }

    /// Hub 双面：`type == 2` → Rahmi；否则 → Lumina Hub
    var hubShowsRahmiFace: Bool { rechargePresentationType == 2 }

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

    nonisolated private static var hasPersistedSuccessfulFetch: Bool {
        UserDefaults.standard.bool(forKey: persistedFetchSucceededKey)
    }

    nonisolated private static func readStoredPresentationTypeNonisolated() -> Int {
        if let raw = UserDefaults.standard.object(forKey: persistedPresentationTypeKey) {
            if let n = raw as? Int, n == 1 || n == 2 { return n }
        }
        if let legacy = UserDefaults.standard.object(forKey: legacyPresentationTypeKey),
           let n = legacy as? Int, n == 1 || n == 2 {
            return n
        }
        return 1
    }

    private func persistSuccessfulPresentationType(_ value: Int) {
        guard value == 1 || value == 2 else { return }
        UserDefaults.standard.set(value, forKey: Self.persistedPresentationTypeKey)
        UserDefaults.standard.set(true, forKey: Self.persistedFetchSucceededKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyPresentationTypeKey)
    }

    func bootstrapOnColdStart() async {
        if Self.hasPersistedSuccessfulFetch {
            let cached = Self.readStoredPresentationTypeNonisolated()
            if rechargePresentationType != cached {
                rechargePresentationType = cached
            }
            print("✅ [VersionConfigStore] app_config 使用本地缓存 type=\(cached)")
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
    }

    func refresh() async {
        await refreshIfNeeded(force: true)
    }

    private func performFirstLaunchBootstrap() async {
        rechargePresentationType = 1
        print("📱 [VersionConfigStore] app_config 首启：默认 Hub(type=1)，等待 AF 后请求")

        let channel = await AppConfig.shared.getChannel()
        let (_, rawAttribution) = await RmThirdPartyAttributionBridge.shared.prepareForFirstLaunch(channelId: channel)
        await applyAppConfigResponse(await requestAppConfig(channel: channel, attribution: rawAttribution))
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
            if let t = resp.type, t == 1 || t == 2 {
                #if DEBUG
                if debugTypeOverrideActive {
                    print("ℹ️ [VersionConfigStore] app_config type=\(t) ignored (DEBUG override, keep \(rechargePresentationType))")
                    return
                }
                #endif
                rechargePresentationType = t
                persistSuccessfulPresentationType(t)
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

    private func applyFirstLaunchFailure(reason: String) {
        rechargePresentationType = 1
        print("❌ [VersionConfigStore] app_config 首启失败(\(reason))，进 Hub(type=1) 且不保存")
    }

    #if DEBUG
    func debugSetPresentationType(_ raw: Int) {
        let v = (raw == 1 || raw == 2) ? raw : 1
        debugTypeOverrideActive = true
        rechargePresentationType = v
        persistSuccessfulPresentationType(v)
        objectWillChange.send()
    }
    #endif
}
