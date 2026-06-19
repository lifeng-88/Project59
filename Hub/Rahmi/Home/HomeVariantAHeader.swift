//
//  HomeVariantAHeader.swift
//  Rahmi
//
//  Home「A 面」顶区：`/v1/version_config` 的 `type == 1` 时与直链内购策略一并启用。
//

import SwiftUI

/// Home A 面：品牌区 + 一级分类 +（可选）视频二级分类条 + 金币入口
struct HomeVariantAHeader: View {
    @EnvironmentObject private var appLanguage: AppLanguageStore
    @Binding var primaryTab: Int
    let primaryTabs: [String]
    let coinBalance: String
    let showVideoCatalogStrip: Bool
    let videoCatalogTitles: [String]
    @Binding var selectedVideoCatalog: Int
    let onCoinTap: () -> Void

    var body: some View {
        let _ = appLanguage.preference
        VStack(alignment: .leading, spacing: 0) {
            heroBlock
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 14)

            primarySegmentRow
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            if showVideoCatalogStrip {
                HomeSecondaryTagStrip(
                    tags: videoCatalogTitles,
                    selected: $selectedVideoCatalog
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.surfaceContainerHigh.opacity(0.92),
                    AppTheme.background.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var heroBlock: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AppLanguageStore.localized("home.variant_a.headline"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accentCyan, AppTheme.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .fixedSize(horizontal: false, vertical: true)
                Text(AppLanguageStore.localized("home.variant_a.subhead"))
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onCoinTap) {
                HStack(spacing: 6) {
                    AppCoinIcon(size: 22)
                    Text(coinBalance)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [AppTheme.accentCyan.opacity(0.55), AppTheme.primary.opacity(0.45)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(AppLanguageStore.localized("tab.recharge")))
        }
    }

    private var primarySegmentRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<min(primaryTabs.count, 3), id: \.self) { idx in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        primaryTab = idx
                    }
                } label: {
                    Text(primaryTabs[idx])
                        .font(.system(size: 14, weight: primaryTab == idx ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(primaryTab == idx ? Color.white : Color.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if primaryTab == idx {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [AppTheme.accentCyan.opacity(0.35), AppTheme.primary.opacity(0.45)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}
