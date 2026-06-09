//
//  PushManager.swift
//  Rahmi
//
//  APNs device token 持久化到 `UserDefaults("rahmi.push_id")`（与 glam `PushManager` 对齐：冷启动即可 `currentPushId()`）；
//  上报 `POST /v1/push_id` 在已登录时异步执行（勿在主线程 await 网络）。失败时挂起，监听 `rahmiAuthSessionDidUpdate` 自动补传。
//

import Foundation
import UIKit
import UserNotifications

/// 推送标识：上报 `POST /v1/push_id` 时使用 APNs device token 的十六进制串。
/// 持久化策略：`UserDefaults` 保存最新 token；APNs 回调每次都覆写。
/// 上报兜底：失败标 `pendingResyncToServer`，下一次 `rahmiAuthSessionDidUpdate`（登录 / refresh / 启动恢复）触发后自动重发。
final class PushManager {
    static let shared = PushManager()

    /// 持久化键：与 glam `PushManager.pushIdKey` 等价；冷启动后立即可用，避免登录请求里 `LoginRequest.pushId == nil`。
    /// glam 用裸 `"push_id"`，这里用带项目前缀的 key，与 keychain / UserDefaults 现有键风格一致。
    private static let pushIdDefaultsKey = "rahmi.push_id"

    private let defaults = UserDefaults.standard
    private let lock = NSLock()
    /// 上一次 `POST /v1/push_id` 失败（含未登录 / 网络 / 401 链路尽头失败）：挂起；监听 `rahmiAuthSessionDidUpdate`
    /// （登录成功 / refresh 成功 / 冷启动恢复）后自动补传一次，避免后端永远没有最新 push_id 导致 APNs 收不到。
    private var pendingResyncToServer: Bool = false

    private init() {
        // 单例永久存活；监听器无需手动移除。会话每次更新都触发一次"按需补传"，幂等接口可重复调用无副作用。
        NotificationCenter.default.addObserver(
            forName: .rahmiAuthSessionDidUpdate,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task.detached(priority: .utility) {
                await self.resyncPushIdToServerIfPending()
            }
        }
    }

    /// 冷启动尽早向 APNs 注册。**横幅/声音权限与 device token 无关**：未决定或已拒绝时也应调用，否则拿不到 token、`/v1/push_id` 无法上报，服务端无法下发（与 Apple「尽早 register」一致）。
    func registerForRemoteNotificationsAtLaunch() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            switch status {
            case .authorized, .provisional, .ephemeral:
                print("📲 [PushManager] Launch: UN 已允许/临时授权 (raw=\(status.rawValue))")
            case .notDetermined:
                print("📲 [PushManager] Launch: UN 未决定 (raw=\(status.rawValue))，仍注册 APNs；要收到横幅请到「我的」相关页或系统设置开启通知")
            case .denied:
                print("📲 [PushManager] Launch: UN 已拒绝 (raw=\(status.rawValue))，仍注册 APNs；要收到锁屏/横幅请在 设置 → 通知 中开启本应用")
            @unknown default:
                print("📲 [PushManager] Launch: UN 未知状态 raw=\(status.rawValue)")
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
                print("📲 [PushManager] Launch: registerForRemoteNotifications()")
            }
        }
    }

    /// 关键业务成功后：未决定则弹系统权限；已允许则再 register 兜底；已拒绝则忽略（可与 glam 任务成功后请求对齐，按需调用）。
    func requestAuthorizationAfterTaskCreatedSuccess() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("📲 [PushManager] Post-task: registerForRemoteNotifications (already authorized)")
                }
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else {
                        print("📲 [PushManager] Post-task: notification permission denied")
                        return
                    }
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                        print("📲 [PushManager] Post-task: registerForRemoteNotifications after grant")
                    }
                }
            case .denied:
                print("📲 [PushManager] Post-task: notification denied in Settings, skip")
            @unknown default:
                break
            }
        }
    }

    func setAPNsDeviceToken(_ data: Data) {
        let hex = data.map { String(format: "%02hhx", $0) }.joined()
        guard !hex.isEmpty else { return }
        // 与 glam 对齐：UserDefaults 持久化；下次冷启动 `currentPushId()` 立即可用，
        // 不再依赖必须先等 APNs 异步回调，登录请求里也能稳定带上 push_id。
        let previous = defaults.string(forKey: Self.pushIdDefaultsKey)
        if previous != hex {
            defaults.set(hex, forKey: Self.pushIdDefaultsKey)
            print("📲 [push_id] \(hex)")
            print("📲 [PushManager] Saved push_id to UserDefaults (\(hex.count) hex chars), changed=true")
            // token 刚轮换：旧 token 的"挂起失败"状态作废，避免老结果误判新 token 也失败。
            markPendingResync(false)
        } else {
            print("📲 [push_id] \(hex)")
            print("📲 [PushManager] Re-registered same push_id (\(hex.count) hex chars), changed=false")
        }
        Task.detached(priority: .utility) {
            await PushManager.shared.syncPushIdToServerIfAuthenticated()
        }
    }

    /// 持久化读取；冷启动即可调用。返回值经 trim，空串视为 nil。
    func currentPushId() -> String? {
        let raw = defaults.string(forKey: Self.pushIdDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (raw?.isEmpty == false) ? raw : nil
    }

    /// 已有 token 且本地已登录时向服务端同步（token 晚于登录回调、或登录成功后补报）。
    /// 失败（未登录 / 网络异常 / `RmHTTPGatewayActor` 401 自动恢复链尽头仍 401）时记 `pendingResyncToServer`，
    /// 待 `rahmiAuthSessionDidUpdate` 触发后由 `resyncPushIdToServerIfPending` 自动补传一次。
    func syncPushIdToServerIfAuthenticated() async {
        guard let hex = currentPushId(), !hex.isEmpty else { return }
        guard let auth = await RmIdentitySessionRepository.shared.getCurrentAuthInfo() else {
            // 拿到 token 但还没登录：标记挂起，等会话更新通知触发补传，避免新设备/重装后首次永远漏报。
            print("📲 [PushManager] currentPushId 已就绪但尚未登录，挂起待 rahmiAuthSessionDidUpdate 后补传")
            markPendingResync(true)
            return
        }
        // 与 glam `PushManager.reportPushIdIfAuthenticated` 对齐：每次上报前强制把 RmHTTPGatewayActor access token
        // 同步为 Keychain 里的最新值。`getCurrentAuthInfo` 命中内存时不会重设 RmHTTPGatewayActor token，若中途被
        // `clearAuthInfo` 冲为 nil（或冷启动注入时序问题）会发出空 `Bearer ` 给 OpenResty 直接 401。
        await RmHTTPGatewayActor.shared.setAccessToken(auth.accessToken)
        print("📲 [push_id] reporting to server: \(hex)")
        let result = await RmIdentityWireTransport.updatePushId(pushId: hex)
        switch result {
        case .success(let ok) where ok:
            markPendingResync(false)
        default:
            // 401 自动 refresh / 设备重登链路若全部失败，会落到这里。挂起后只需任意一次会话更新通知就会自愈。
            print("📲 [PushManager] /v1/push_id 上报未成功，挂起待下次 rahmiAuthSessionDidUpdate 后补传")
            markPendingResync(true)
        }
    }

    /// 与 glam `reportPushIdIfAuthenticated(pushId:)` 命名/语义对齐：直接传入刚拿到的 token，避免依赖 `currentPushId()`
    /// 的持久化读时序。委托内部仍走 `syncPushIdToServerIfAuthenticated` 完成失败兜底。
    func reportPushIdIfAuthenticated(pushId: String) async {
        let trimmed = pushId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 持久化覆写一次，确保 `currentPushId()` 与本次上报的 token 一致；后续 `LoginRequest.pushId` / 兜底重传都用同一份。
        if defaults.string(forKey: Self.pushIdDefaultsKey) != trimmed {
            defaults.set(trimmed, forKey: Self.pushIdDefaultsKey)
        }
        await syncPushIdToServerIfAuthenticated()
    }

    /// 收到 `rahmiAuthSessionDidUpdate`（access token 刷新 / 设备重登 / 启动恢复会话）后调用：
    /// 仅在挂起且具备登录态时再尝试一次；幂等，重复触发也只发一次请求。
    private func resyncPushIdToServerIfPending() async {
        guard isPendingResync() else { return }
        guard currentPushId() != nil else { return }
        guard await RmIdentitySessionRepository.shared.getCurrentAuthInfo() != nil else { return }
        print("📲 [PushManager] 检测到 rahmiAuthSessionDidUpdate，补传上次失败的 push_id")
        await syncPushIdToServerIfAuthenticated()
    }

    private func isPendingResync() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingResyncToServer
    }

    private func markPendingResync(_ pending: Bool) {
        lock.lock()
        defer { lock.unlock() }
        pendingResyncToServer = pending
    }
}
