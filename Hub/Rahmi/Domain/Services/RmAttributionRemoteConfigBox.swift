//
//  RmAttributionRemoteConfigBox.swift
//  Rahmi
//
//  T-AF-4：与 glam `AFConfigManager` 对齐。
//  从 `RES_BASE_URL/config/{channel_id}.json` 拉取，解析 `apple_app_id`、`apps_flyer_dev_key`；
//  键与 channel_id 关联；仅在本机无有效缓存时拉取。失败不阻塞启动。
//

import Foundation

/// AF 静态配置 JSON（支持 snake_case 与 camelCase）
private struct AFConfigPayload: Decodable {
    var apple_app_id: String?
    var apps_flyer_dev_key: String?
    var appleAppId: String?
    var appsFlyerDevKey: String?

    var resolvedAppleAppId: String? { apple_app_id ?? appleAppId }
    var resolvedAppsFlyerDevKey: String? { apps_flyer_dev_key ?? appsFlyerDevKey }
}

/// AppsFlyer 配置：拉取并缓存 Apple App ID、AppsFlyer Dev Key
actor RmAttributionRemoteConfigBox {
    static let shared = RmAttributionRemoteConfigBox()

    private let defaults = UserDefaults.standard
    private var inflightFetches: [String: Task<(appleAppId: String, appsFlyerDevKey: String)?, Never>] = [:]

    private init() {}

    // MARK: - Keys (per channel_id)

    private func keyAppleAppID(_ channelId: String) -> String {
        "af_apple_app_id_\(channelId)"
    }

    private func keyAppsFlyerDevKey(_ channelId: String) -> String {
        "af_apps_flyer_dev_key_\(channelId)"
    }

    private func effectiveChannelId(_ channelId: String) -> String {
        let trimmed = channelId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? AppConfig.buildDefaultChannelId : trimmed
    }

    // MARK: - Public API

    /// 获取 Apple App ID：先读本地，无则拉取再写本地
    func getAppleAppID(channelId: String) async -> String? {
        let effectiveChannel = effectiveChannelId(channelId)
        if let cached = defaults.string(forKey: keyAppleAppID(effectiveChannel)), !cached.isEmpty {
            print("📱 [AFConfig] getAppleAppID: 使用本地缓存 channel=\(effectiveChannel)")
            return cached
        }
        print("📱 [AFConfig] getAppleAppID: 无缓存 channel=\(effectiveChannel)，拉取 config")
        if let (appleAppId, _) = await fetchAndCacheConfig(channelId: effectiveChannel) {
            return appleAppId
        }
        print("📱 [AFConfig] getAppleAppID: 拉取失败 channel=\(effectiveChannel)")
        return nil
    }

    /// 获取 AppsFlyer Dev Key：先读本地，无则拉取再写本地
    func getAppsFlyerDevKey(channelId: String) async -> String? {
        let effectiveChannel = effectiveChannelId(channelId)
        if let cached = defaults.string(forKey: keyAppsFlyerDevKey(effectiveChannel)), !cached.isEmpty {
            print("📱 [AFConfig] getAppsFlyerDevKey: 使用本地缓存 channel=\(effectiveChannel)")
            return cached
        }
        print("📱 [AFConfig] getAppsFlyerDevKey: 无缓存 channel=\(effectiveChannel)，拉取 config")
        if let (_, devKey) = await fetchAndCacheConfig(channelId: effectiveChannel) {
            return devKey
        }
        print("📱 [AFConfig] getAppsFlyerDevKey: 拉取失败 channel=\(effectiveChannel)")
        return nil
    }

    /// 拉取静态 config 并写入 UserDefaults，失败不抛错
    private func fetchAndCacheConfig(channelId: String) async -> (appleAppId: String, appsFlyerDevKey: String)? {
        if let inflight = inflightFetches[channelId] {
            return await inflight.value
        }

        let task = Task<(appleAppId: String, appsFlyerDevKey: String)?, Never> {
            await Self.performFetchAndCache(channelId: channelId, defaults: UserDefaults.standard)
        }
        inflightFetches[channelId] = task
        let result = await task.value
        inflightFetches[channelId] = nil
        return result
    }

    private static func performFetchAndCache(
        channelId: String,
        defaults: UserDefaults
    ) async -> (appleAppId: String, appsFlyerDevKey: String)? {
        guard let url = ResBaseURL.channelConfigURL(for: channelId) else {
            print("⚠️ [AFConfig] fetchAndCacheConfig: Invalid URL channel=\(channelId)")
            return nil
        }
        print("📱 [AFConfig] fetchAndCacheConfig: URL=\(url.absoluteString)")

        do {
            let (data, response) = try await fetchSession.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("⚠️ [AFConfig] fetchAndCacheConfig: HTTP status=\((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            let payload = try JSONDecoder().decode(AFConfigPayload.self, from: data)
            guard let appleAppId = payload.resolvedAppleAppId?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !appleAppId.isEmpty,
                  let devKey = payload.resolvedAppsFlyerDevKey?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !devKey.isEmpty else {
                print("⚠️ [AFConfig] fetchAndCacheConfig: 缺少 apple_app_id 或 apps_flyer_dev_key")
                return nil
            }
            defaults.set(appleAppId, forKey: "af_apple_app_id_\(channelId)")
            defaults.set(devKey, forKey: "af_apps_flyer_dev_key_\(channelId)")
            print("✅ [AFConfig] fetchAndCacheConfig: 成功 channel=\(channelId) appleAppId=\(appleAppId.prefix(min(12, appleAppId.count)))...")
            return (appleAppId, devKey)
        } catch {
            print("⚠️ [AFConfig] fetchAndCacheConfig: 请求失败 \(error.localizedDescription)")
            return nil
        }
    }

    /// 与 API 客户端一致：绕过本机 HTTP 代理，避免 Simulator TLS 异常
    private static let fetchSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.waitsForConnectivity = true
        configuration.connectionProxyDictionary = [
            "HTTPEnable": 0,
            "HTTPSEnable": 0,
            "SOCKSEnable": 0
        ]
        return URLSession(configuration: configuration)
    }()
}
