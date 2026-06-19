//
//  RechargeVariantAHeader.swift
//  Rahmi
//
//  充值页 A 面：`/v1/version_config` 的 `type == 1`（直链 App Store 内购）时与 `RechargeView` 主列表同屏展示。
//

import SwiftUI

/// 充值 A 面：品牌说明区 + App Store 内购说明（余额见导航栏右上角）
struct RechargeVariantAHeader: View {
    @EnvironmentObject private var appLanguage: AppLanguageStore

    var body: some View {
        let _ = appLanguage.preference
        VStack(alignment: .leading, spacing: 10) {
            Text(AppLanguageStore.localized("recharge.variant_a.headline"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.accentCyan, AppTheme.primary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .fixedSize(horizontal: false, vertical: true)

            Text(AppLanguageStore.localized("recharge.variant_a.subhead"))
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                Text(AppLanguageStore.localized("recharge.variant_a.iap_hint"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.vertical, 14)
        .padding(.bottom, 6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.09),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

/// A 面充值 / 内购弹层共用的 String Catalog 键选择（与 `RechargeView`、`HomeGenerationRechargeUpsellView` 对齐）
enum RechargeVariantALocalization {
    static func footerKey(isVariantA: Bool) -> String {
        isVariantA ? "recharge.variant_a.iap_hint" : "recharge.secure_footer"
    }

    static func processingKey(isVariantA: Bool) -> String {
        isVariantA ? "recharge.variant_a.processing" : "recharge.processing"
    }

    static func primaryCTAKey(isVariantA: Bool, isPurchasing: Bool) -> String {
        if isPurchasing { return processingKey(isVariantA: isVariantA) }
        return isVariantA ? "recharge.variant_a.primary_cta" : "recharge.now"
    }

    static func navigationTitleKey(isVariantA: Bool) -> String {
        isVariantA ? "recharge.variant_a.headline" : "recharge.list_title"
    }

    static func upsellHeaderTitleKey(isVariantA: Bool) -> String {
        isVariantA ? "recharge.variant_a.headline" : "recharge.list_title"
    }
}
