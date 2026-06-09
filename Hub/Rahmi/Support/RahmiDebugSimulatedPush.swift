//
//  RahmiDebugSimulatedPush.swift
//  Rahmi
//
//  DEBUG：模拟远程推送载荷与本地通知调度（原「我的」页底版本号入口，可复用于首页 DEBUG 面板）。
//

#if DEBUG

import Foundation
import UIKit
import UserNotifications

/// 与网关约定一致的 `RemotePushRoute` + APNs `userInfo`，仅用于本机调试。
struct SimPushDebugPayload {
    let title: String
    let body: String
    let detailText: String
    let userInfo: [String: Any]
    let route: RemotePushRoute
}

enum RahmiDebugSimulatedPush {
    static let cases: [SimPushDebugPayload] = [
        SimPushDebugPayload(
            title: "Rahmi ✨",
            body: "你的创作已生成，点击查看",
            detailText: "push_type: generation_success\ntask_id: 1775043463758460903",
            userInfo: [
                "push_type": "generation_success",
                "task_id": "1775043463758460903"
            ],
            route: .generationSuccess(taskId: "1775043463758460903")
        ),
        SimPushDebugPayload(
            title: "Rahmi",
            body: "创作未能完成，点击查看任务详情",
            detailText: "push_type: generation_failure\ntask_id: 1775043463758460903",
            userInfo: [
                "push_type": "generation_failure",
                "task_id": "1775043463758460903"
            ],
            route: .generationFailure(taskId: "1775043463758460903")
        ),
        SimPushDebugPayload(
            title: "Rahmi",
            body: "客服回复了你的反馈，点击查看",
            detailText: "push_type: feedback_reply\nfeedback_id: 10001\ncampaign_id: test_d7",
            userInfo: [
                "push_type": "feedback_reply",
                "feedback_id": "10001",
                "campaign_id": "test_d7"
            ],
            route: .feedbackReply(feedbackId: "10001", campaignId: "test_d7")
        ),
        SimPushDebugPayload(
            title: "Rahmi",
            body: "送你 500 金币，点击领取",
            detailText: "push_type: return_user_coins_claim\nclaim_id: claim_001\ncampaign_id: cmp_2\nreward_coins: 500",
            userInfo: [
                "push_type": "return_user_coins_claim",
                "claim_id": "claim_001",
                "campaign_id": "cmp_2",
                "reward_coins": 500
            ],
            route: .returnUserCoinsClaim(
                ReturnUserCoinsClaimPayload(claimId: "claim_001", campaignId: "cmp_2", rewardCoins: 500)
            )
        ),
        SimPushDebugPayload(
            title: "Rahmi",
            body: "新用户专享充值优惠，点击查看",
            detailText: """
            push_type: recharge_incentive_new_user
            offer_id: offer_001
            apple_product_id: com.xmglamai.glamai.consumable.coins_20
            campaign_id: cmp_1
            amount_cents_usd: 499 / base_coins: 1000 / bonus_coins: 2000
            """,
            userInfo: [
                "push_type": "recharge_incentive_new_user",
                "offer_id": "offer_001",
                "apple_product_id": "com.xmglamai.glamai.consumable.coins_20",
                "campaign_id": "cmp_1",
                "amount_cents_usd": 499,
                "base_coins": 1000,
                "bonus_coins": 2000
            ],
            route: .rechargeIncentiveNewUser(
                RechargeNewUserOfferPayload(
                    offerId: "offer_001",
                    appleProductId: "com.xmglamai.glamai.consumable.coins_20",
                    campaignId: "cmp_1",
                    amountCentsUsd: 499,
                    baseCoins: 1000,
                    bonusCoins: 2000
                )
            )
        ),
        SimPushDebugPayload(
            title: "Rahmi",
            body: "新模板已上线，点击探索",
            detailText: "push_type: template_category\ntemplate_tab_id: 3\ncatalog_id: 1\ncampaign_id: test_cat",
            userInfo: [
                "push_type": "template_category",
                "template_tab_id": 3,
                "catalog_id": 1,
                "campaign_id": "test_cat"
            ],
            route: .templateCategory(
                HomeTemplateCategoryPush(templateTabId: 3, catalogId: 1, campaignId: "test_cat")
            )
        )
    ]

    /// 循环下一条模拟推送说明（与旧版「我的」底栏点击一致）。
    static func advanceStep(_ step: inout Int) -> SimPushDebugPayload {
        let idx = step % cases.count
        step += 1
        return cases[idx]
    }

    /// 与服务端 APNs `userInfo` 字段一致：调度一次本地通知，由 `BBBPushNotificationCenterDelegate.didReceive`
    /// 走真实点击流程解析 `RemotePushRoute` 并 `dispatchRemotePush`。
    static func send(_ payload: SimPushDebugPayload) {
        Task { @MainActor in
            let resolved = await resolveWithRealTaskIfNeeded(payload)
            scheduleLocalNotification(resolved)
        }
    }

    private static func scheduleLocalNotification(_ payload: SimPushDebugPayload) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        let pushType = (payload.userInfo["push_type"] as? String) ?? "-"
        let taskId = (payload.userInfo["task_id"] as? String) ?? "-"
        print("📲 [SimPush] 调度本地通知 push_type=\(pushType) task_id=\(taskId)")
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default
        var userInfo: [AnyHashable: Any] = [:]
        for (k, v) in payload.userInfo {
            userInfo[k] = v
        }
        content.userInfo = userInfo
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "SimPush-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error {
                print("📲 [SimPush] 调度本地通知失败 push_type=\(pushType): \(error.localizedDescription)")
            } else {
                print("📲 [SimPush] 已入队，约 1s 后弹出 push_type=\(pushType)")
            }
        }
    }

    @MainActor
    private static func resolveWithRealTaskIfNeeded(_ payload: SimPushDebugPayload) async -> SimPushDebugPayload {
        let pushType = (payload.userInfo["push_type"] as? String) ?? ""
        guard pushType == "generation_success" || pushType == "generation_failure" else {
            return payload
        }
        let result = await RmAsyncRenderJobWireTransport.getTaskList(pageNum: Int32(1), pageSize: Int32(50))
        guard case .success(let resp) = result else {
            print("📲 [SimPush] 获取真实 task 列表失败，沿用占位 task_id 发送（推送目标页会显示 task not found）")
            return payload
        }
        let preferredStatus: Int32 = pushType == "generation_success" ? 2 : 3
        let chosen = resp.list.first { $0.status == preferredStatus } ?? resp.list.first
        guard let item = chosen else {
            print("📲 [SimPush] 账号下暂无任务，沿用占位 task_id 发送（推送目标页会显示 task not found）")
            return payload
        }
        var newUserInfo = payload.userInfo
        newUserInfo["task_id"] = item.taskId
        let detail = "push_type: \(pushType)\ntask_id: \(item.taskId) (real, status=\(item.status))"
        print("📲 [SimPush] 已用真实 task_id=\(item.taskId) (status=\(item.status)) 替换占位")
        let route: RemotePushRoute = pushType == "generation_success"
            ? .generationSuccess(taskId: item.taskId)
            : .generationFailure(taskId: item.taskId)
        return SimPushDebugPayload(
            title: payload.title,
            body: payload.body,
            detailText: detail,
            userInfo: newUserInfo,
            route: route
        )
    }
}

#endif
