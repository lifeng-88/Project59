//
//  RmThirdPartyAttributionBridge.swift
//  glam
//
//  T-AF-5 / T-AF-7: AF SDK 初始化与首启归因流程；非首启异步初始化
//  首启：拉取 config → 初始化 AF → start() 等归因（或 10 秒超时）→ 再允许登录
//  非首启：直接允许登录，仅多一步后台异步初始化 AF
//  需在 Xcode 中通过 File > Add Package 添加: https://github.com/AppsFlyerSDK/AppsFlyerFramework-Static，产品选 AppsFlyerLib
//

import Foundation

private let kAFHasObtainedAttribution = "af_has_obtained_attribution"
private let kAFHasCompletedLogin = "af_has_completed_login"
private let kAFAttributionJSON = "af_attribution_json"
private let kAFAfId = "af_af_id"
private let kAFAdId = "af_ad_id"
private let kAFSource = "af_source"
private let attributionTimeoutSeconds: TimeInterval = 10

/// AF 归因结果，用于登录请求
struct AFAttributionResult {
    var afId: String?
    var adId: String?
    var source: String?
    var attributionJson: String?

    /// AF 等待超时或未拿到归因时的占位 JSON（与 ReelMix `AFAttributionResult.timeoutFallback` 一致）
    static func timeoutFallback() -> AFAttributionResult {
        let timeoutJson = (try? JSONSerialization.data(withJSONObject: ["timeout": true]))
            .flatMap { String(data: $0, encoding: .utf8) }
        return AFAttributionResult(afId: nil, adId: nil, source: nil, attributionJson: timeoutJson)
    }
}

/// AppsFlyer 服务：归因状态与登录就绪
actor RmThirdPartyAttributionBridge {
    static let shared = RmThirdPartyAttributionBridge()

    private let defaults = UserDefaults.standard
    private var attributionResult: AFAttributionResult?
    private var attributionContinuation: CheckedContinuation<AFAttributionResult?, Never>?
    private let configManager = RmAttributionRemoteConfigBox.shared

    private init() {}

    /// 是否已获取过归因
    var hasObtainedAttributionBefore: Bool {
        defaults.bool(forKey: kAFHasObtainedAttribution)
    }

    /// 是否曾完成过登录（首启判断标准：未完成过登录 = 首启）
    var hasCompletedLoginBefore: Bool {
        defaults.bool(forKey: kAFHasCompletedLogin)
    }

    /// 标记已完成登录（由 RmIdentitySessionRepository 在登录成功时调用）
    func markLoginCompleted() {
        let wasFirstCompletedLogin = !hasCompletedLoginBefore
        defaults.set(true, forKey: kAFHasCompletedLogin)
        AFSDKBridge.logLogin()
        if wasFirstCompletedLogin {
            AFSDKBridge.logCompleteRegistration()
        }
        print("📱 [RmThirdPartyAttributionBridge] markLoginCompleted: 已标记曾完成登录")
    }

    /// 当前缓存的归因结果（供登录携带）
    func getAttributionForLogin() -> AFAttributionResult? {
        if let r = attributionResult { return r }
        let afId = defaults.string(forKey: kAFAfId)
        let adId = defaults.string(forKey: kAFAdId)
        let source = defaults.string(forKey: kAFSource)
        let json = defaults.string(forKey: kAFAttributionJSON)
        if afId != nil || adId != nil || source != nil || (json != nil && !json!.isEmpty) {
            return AFAttributionResult(afId: afId, adId: adId, source: source, attributionJson: json)
        }
        return nil
    }

    /// 设置归因结果（由 AF delegate 或测试调用）
    func setAttribution(afId: String?, adId: String?, source: String?, attributionJson: String?) {
        attributionResult = AFAttributionResult(afId: afId, adId: adId, source: source, attributionJson: attributionJson)
        if let afId = afId, !afId.isEmpty { defaults.set(afId, forKey: kAFAfId) }
        if let adId = adId { defaults.set(adId, forKey: kAFAdId) }
        if let source = source { defaults.set(source, forKey: kAFSource) }
        if let json = attributionJson { defaults.set(json, forKey: kAFAttributionJSON) }
        defaults.set(true, forKey: kAFHasObtainedAttribution)
        print("📱 [RmThirdPartyAttributionBridge] setAttribution: afId=\(afId ?? "nil") source=\(source ?? "nil") jsonLen=\(attributionJson?.count ?? 0)")
        if let cont = attributionContinuation {
            attributionContinuation = nil
            cont.resume(returning: attributionResult)
            print("📱 [RmThirdPartyAttributionBridge] setAttribution: 已 resume 等待中的归因")
        }
    }

    /// 首启时等待归因或超时，返回用于登录的归因数据
    func waitForAttributionOrTimeout() async -> AFAttributionResult? {
        if hasObtainedAttributionBefore {
            let cached = getAttributionForLogin()
            print("📱 [RmThirdPartyAttributionBridge] waitForAttributionOrTimeout: 已有归因缓存，直接返回")
            return cached
        }
        print("📱 [RmThirdPartyAttributionBridge] waitForAttributionOrTimeout: 等待归因，超时 \(Int(attributionTimeoutSeconds))s")
        /// 外层任务被取消时必须 resume continuation，否则运行库可能报 continuation / executor 相关异常（如 “invalid reuse after initialization failure” 一类症状）。
        let result = await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { (continuation: CheckedContinuation<AFAttributionResult?, Never>) in
                if let stale = self.attributionContinuation {
                    self.attributionContinuation = nil
                    stale.resume(returning: self.getAttributionForLogin())
                }
                self.attributionContinuation = continuation
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(attributionTimeoutSeconds * 1_000_000_000))
                    await self.timeoutAttribution()
                }
            }
        }, onCancel: {
            Task { await RmThirdPartyAttributionBridge.shared.resumeAttributionWaitCancelled() }
        })
        if result != nil {
            print("📱 [RmThirdPartyAttributionBridge] waitForAttributionOrTimeout: 得到归因 afId=\(result?.afId ?? "nil") source=\(result?.source ?? "nil")")
        } else {
            print("📱 [RmThirdPartyAttributionBridge] waitForAttributionOrTimeout: 超时或无归因，返回 nil")
        }
        return result
    }

    /// 等待归因的任务被取消时：结束挂起的 continuation，避免泄漏或未定义行为。
    private func resumeAttributionWaitCancelled() {
        guard let cont = attributionContinuation else { return }
        attributionContinuation = nil
        cont.resume(returning: getAttributionForLogin())
        print("📱 [RmThirdPartyAttributionBridge] resumeAttributionWaitCancelled: 已因取消 resume")
    }

    private func timeoutAttribution() async {
        if let cont = attributionContinuation {
            attributionContinuation = nil
            defaults.set(true, forKey: kAFHasObtainedAttribution)
            cont.resume(returning: getAttributionForLogin())
            print("📱 [RmThirdPartyAttributionBridge] timeoutAttribution: 超时，已 resume")
        }
    }

    /// 首启：拉取 config、初始化 AF、start()，然后等待归因或超时
    /// 返回 (canLogin, attributionForLogin)。失败不阻塞，返回 (true, nil)
    func prepareForFirstLaunch(channelId: String) async -> (canLogin: Bool, attribution: AFAttributionResult?) {
        let effectiveChannel = channelId.isEmpty ? AppConfig.buildDefaultChannelId : channelId
        print("📱 [RmThirdPartyAttributionBridge] prepareForFirstLaunch: 开始 channel=\(effectiveChannel)")
        #if DEBUG
        if ProcessInfo.processInfo.environment["SIMULATE_AF_TIMEOUT"] == "1" {
            print("🧪 [RmThirdPartyAttributionBridge] prepareForFirstLaunch: 模拟 AF 超时 (SIMULATE_AF_TIMEOUT=1)，跳过等待，返回 nil")
            return (true, nil)
        }
        #endif
        guard let appleAppId = await configManager.getAppleAppID(channelId: effectiveChannel),
              let devKey = await configManager.getAppsFlyerDevKey(channelId: effectiveChannel),
              !appleAppId.isEmpty, !devKey.isEmpty else {
            print("⚠️ [RmThirdPartyAttributionBridge] prepareForFirstLaunch: 无 AF config，跳过 init channel=\(effectiveChannel)")
            return (true, nil)
        }
        print("📱 [RmThirdPartyAttributionBridge] prepareForFirstLaunch: 配置 AF 并 start，等待归因")
        AFSDKBridge.configure(appleAppId: appleAppId, appsFlyerDevKey: devKey)
        AFSDKBridge.start()
        let attribution = await waitForAttributionOrTimeout()
        print("📱 [RmThirdPartyAttributionBridge] prepareForFirstLaunch: 完成 attribution=\(attribution != nil ? "有" : "无")")
        return (true, attribution)
    }

    /// 非首启：后台异步初始化 AF，不等待归因、不阻塞登录
    func initAFAsync(channelId: String) async {
        let effectiveChannel = channelId.isEmpty ? AppConfig.buildDefaultChannelId : channelId
        print("📱 [RmThirdPartyAttributionBridge] initAFAsync: 开始 channel=\(effectiveChannel)")
        guard let appleAppId = await configManager.getAppleAppID(channelId: effectiveChannel),
              let devKey = await configManager.getAppsFlyerDevKey(channelId: effectiveChannel),
              !appleAppId.isEmpty, !devKey.isEmpty else {
            print("📱 [RmThirdPartyAttributionBridge] initAFAsync: 无 AF config，跳过 channel=\(effectiveChannel)")
            return
        }
        AFSDKBridge.configure(appleAppId: appleAppId, appsFlyerDevKey: devKey)
        AFSDKBridge.start()
        print("📱 [RmThirdPartyAttributionBridge] initAFAsync: 完成 channel=\(effectiveChannel)")
    }
}

/// 桥接层：无 SDK 时 no-op；添加 AppsFlyerLib 后在此调用真实 API（Xcode: File > Add Package > https://github.com/AppsFlyerSDK/AppsFlyerFramework-Static）
enum AFSDKBridge {
    static func configure(appleAppId: String, appsFlyerDevKey: String) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().appleAppID = appleAppId
        AppsFlyerLib.shared().appsFlyerDevKey = appsFlyerDevKey
        AppsFlyerLib.shared().delegate = AFDelegateWrapper.shared
        print("📱 [AFSDKBridge] configure: 已配置 appleAppId=\(appleAppId.prefix(12))... devKey=\(appsFlyerDevKey.prefix(8))...")
        #else
        _ = appleAppId; _ = appsFlyerDevKey
        print("ℹ️ [AFSDKBridge] configure: AppsFlyerLib 未链接，no-op")
        #endif
    }

    static func start() {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().start()
        print("📱 [AFSDKBridge] start: 已调用 AF start()")
        #else
        print("ℹ️ [AFSDKBridge] start: AppsFlyerLib 未链接，no-op")
        #endif
    }

    /// 与官方建议一致：每次进入前台调用 `start()`（已 configure 时安全；未 configure 时无效果）
    static func handleBecomeActive() {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().start()
        #endif
    }

    /// 首次在本机完成登录（设备登录成功）时上报，供 Meta 等集成映射 **`CompleteRegistration`**。
    /// 控制台请将 **`af_complete_registration`** 映射到伙伴事件，勿用 **`af_app_opened`** 代替（后者为会话打开，语义不符）。
    static func logCompleteRegistration() {
        #if canImport(AppsFlyerLib)
        let values: [String: Any] = [
            "af_registration_method": "device"
        ]
        AppsFlyerLib.shared().logEvent("af_complete_registration", withValues: values)
        print("📱 [AFSDKBridge] logCompleteRegistration: af_complete_registration sent")
        #else
        print("ℹ️ [AFSDKBridge] logCompleteRegistration: AppsFlyerLib 未链接，no-op")
        #endif
    }

    /// 每次设备登录成功时上报，使用 AppsFlyer 标准事件 **`af_login`**。
    /// 控制台可将该事件映射到对应伙伴事件（如 Meta 的 `Login`）。
    static func logLogin() {
        #if canImport(AppsFlyerLib)
        let values: [String: Any] = [
            "af_login_method": "device"
        ]
        AppsFlyerLib.shared().logEvent("af_login", withValues: values)
        print("📱 [AFSDKBridge] logLogin: af_login sent")
        #else
        print("ℹ️ [AFSDKBridge] logLogin: AppsFlyerLib 未链接，no-op")
        #endif
    }
}

#if canImport(AppsFlyerLib)
import AppsFlyerLib

private final class AFDelegateWrapper: NSObject, AppsFlyerLibDelegate {
    static let shared = AFDelegateWrapper()
    override private init() { super.init() }
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        let afId = AppsFlyerLib.shared().getAppsFlyerUID()
        let json: String? = (try? JSONSerialization.data(withJSONObject: conversionInfo)).flatMap { String(data: $0, encoding: .utf8) }
        let source = conversionInfo["media_source"] as? String
        print("📱 [AFDelegate] onConversionDataSuccess: afId=\(afId ?? "nil") source=\(source ?? "nil")")
        Task { await RmThirdPartyAttributionBridge.shared.setAttribution(afId: afId, adId: nil, source: source, attributionJson: json) }
    }
    func onConversionDataFail(_ error: Error) {
        print("📱 [AFDelegate] onConversionDataFail: \(error.localizedDescription)")
        Task { await RmThirdPartyAttributionBridge.shared.setAttribution(afId: nil, adId: nil, source: nil, attributionJson: nil) }
    }
}
#endif
