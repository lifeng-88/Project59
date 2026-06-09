//
//  HomeFlashSalePresentation.swift
//  Rahmi
//
//  限时折扣展示逻辑与倒计时条：沉浸式主按钮、模板详情预览底栏等共用（与 Glam `isFlashSaleActive` 语义对齐）。
//

import SwiftUI

enum HomeFlashSalePresentation {
    /// `discountEndsAt` 未过期且存在可展示的原价→现价折扣（0%＜折扣＜100%）。
    static func isFlashSaleActive(_ item: HomeFeedItem, now: Date) -> Bool {
        guard item.isDiscountActive(now: now) else { return false }
        guard let o = item.originalConsumedCoins, o > item.consumedCoins, o > 0 else { return false }
        let pct = Int(round(100.0 * Double(o - item.consumedCoins) / Double(o)))
        return pct > 0 && pct < 100
    }

    static func discountPercent(_ item: HomeFeedItem) -> Int? {
        guard let o = item.originalConsumedCoins, o > item.consumedCoins, o > 0 else { return nil }
        let pct = Int(round(100.0 * Double(o - item.consumedCoins) / Double(o)))
        guard pct > 0, pct < 100 else { return nil }
        return pct
    }

    /// 总剩余秒数：`H:MM:SS`（小时可大于 99）或 `MM:SS`。
    static func countdownText(_ item: HomeFeedItem, now: Date) -> String? {
        guard isFlashSaleActive(item, now: now) else { return nil }
        guard let endsAt = item.discountEndsAt else { return nil }
        let remaining = max(0, Int(endsAt - now.timeIntervalSince1970))
        guard remaining > 0 else { return nil }
        let h = remaining / 3600
        let m = (remaining % 3600) / 60
        let s = remaining % 60
        if h > 0 {
            return "\(h):\(String(format: "%02d", m)):\(String(format: "%02d", s))"
        }
        return String(format: "%02d:%02d", m, s)
    }
}

/// 闪电 + 金色倒计时条（深色底 + 渐变描边 + 轻脉冲光）。
struct HomeFlashSaleCountdownBar: View {
    let countdown: String
    @State private var glowPulse: CGFloat = 0

    private let gold = Color(red: 250 / 255, green: 204 / 255, blue: 21 / 255)
    private let pink = Color(red: 224 / 255, green: 56 / 255, blue: 157 / 255)
    private let purple = Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255)

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [gold, gold.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                )
            Text(countdown)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(gold)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.75), Color.black.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [gold.opacity(0.85), pink.opacity(0.5), purple.opacity(0.4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color: gold.opacity(0.22 + 0.12 * glowPulse), radius: 4 + 3 * glowPulse, x: 0, y: 0)
        .shadow(color: pink.opacity(0.06), radius: 5, x: 0, y: 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glowPulse = 1
            }
        }
    }
}
