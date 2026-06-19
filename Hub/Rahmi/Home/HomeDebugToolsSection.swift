//
//  HomeDebugToolsSection.swift
//  Rahmi
//
//  DEBUG：首页底部调试列表（version type 切换、模拟推送、生成成功/生成中预览）。
//

#if DEBUG

import SwiftUI
import UIKit

extension TaskListItem {
    /// 本地预览用成功任务：`picsum` 稳定可拉图；`userParams == nil` 关闭 Reroll（无真实模板）；`tid` 空则无收藏键。
    static func rahmiDebugPreviewSuccess() -> TaskListItem {
        TaskListItem(
            taskId: "rahmi_debug_success_ui",
            taskType: 1,
            tid: "",
            totalStage: nil,
            currentStage: nil,
            status: 2,
            userParams: nil,
            resultUrl: "https://picsum.photos/id/866/720/1280",
            createTs: "0",
            execTs: nil,
            finishTs: nil,
            waitSeconds: nil,
            execSeconds: nil,
            readStatus: nil,
            consumedGold: 1
        )
    }
}

/// 叠在 **TabBar 之上**（由 `MainTabView.safeAreaInset` 挂载）；仅 DEBUG 编译。默认收起为一条底栏，展开后使用调试项。
struct HomeDebugToolsSection: View {
    @EnvironmentObject private var versionConfig: VersionConfigStore
    @EnvironmentObject private var wallet: UserWalletStore
    @EnvironmentObject private var auth: AuthSessionStore
    @EnvironmentObject private var tabRouter: AppTabRouter
    @EnvironmentObject private var appLanguage: AppLanguageStore

    /// 收起胶囊与展开列表共用最大宽度，避免拉满整屏。
    private static let panelMaxWidth: CGFloat = 360

    @State private var isExpanded = false
    @State private var simPushStep = 0
    @State private var simPushPayload: SimPushDebugPayload?
    @State private var showDebugGenerationSuccess = false
    @State private var showDebugGenerating = false

    var body: some View {
        let _ = appLanguage.preference
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 16)
                collapseToggleBar
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, isExpanded ? 6 : 4)

            if isExpanded {
                HStack {
                    Spacer(minLength: 16)
                    VStack(spacing: 0) {
                        if !versionConfig.isPresentationVariantAUIEnabled {
                            debugRow(title: "正 / 测（type）", trailing: versionConfig.rechargePresentationType == 1 ? "1 · 正" : "2 · 测") {
                                let next = versionConfig.rechargePresentationType == 1 ? 2 : 1
                                versionConfig.debugSetPresentationType(next)
                            }

                            Divider().opacity(0.35)
                        }

                        debugRow(title: "模拟推送", trailing: "›") {
                            simPushPayload = RahmiDebugSimulatedPush.advanceStep(&simPushStep)
                        }

                        Divider().opacity(0.35)

                        debugRow(title: "模拟创作生成成功", trailing: "›") {
                            showDebugGenerationSuccess = true
                        }

                        Divider().opacity(0.35)

                        debugRow(title: "模拟生成中", trailing: "›") {
                            showDebugGenerating = true
                        }
                    }
                    .frame(maxWidth: Self.panelMaxWidth)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.surfaceContainer.opacity(0.96))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.outlineVariant.opacity(0.25), lineWidth: 1)
                    )
                    Spacer(minLength: 16)
                }
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isExpanded)
        .alert(
            "模拟推送",
            isPresented: Binding(
                get: { simPushPayload != nil },
                set: { if !$0 { simPushPayload = nil } }
            ),
            actions: {
                Button("关闭", role: .cancel) { simPushPayload = nil }
                Button("发送通知") {
                    if let p = simPushPayload {
                        RahmiDebugSimulatedPush.send(p)
                    }
                    simPushPayload = nil
                }
            },
            message: {
                if let p = simPushPayload {
                    Text(p.detailText)
                }
            }
        )
        .fullScreenCover(isPresented: $showDebugGenerationSuccess) {
            NavigationView {
                GenerationSuccessView(item: .rahmiDebugPreviewSuccess(), onRerollSuccess: nil)
                    /// 随 `type` 变化重建，避免复用上一档 A/B。
                    .id(versionConfig.rechargePresentationType)
                    .environment(\.rahmiGenerationSuccessHostDismiss) {
                        showDebugGenerationSuccess = false
                    }
            }
            .environmentObject(auth)
            .environmentObject(wallet)
            .environmentObject(appLanguage)
            .environmentObject(tabRouter)
            .environmentObject(versionConfig)
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .fullScreenCover(isPresented: $showDebugGenerating) {
            ZStack(alignment: .top) {
                HomeGenerationQueuingView(
                    item: HomeFeedItem.sampleFeed[0],
                    sourceImage: Self.debugPlaceholderPortrait(),
                    isSubmitting: false,
                    onBrowseOther: {
                        showDebugGenerating = false
                        RmAsyncWorkPollCoordinator.shared.reset()
                    },
                    onTaskSucceeded: { _ in }
                )
                .environmentObject(versionConfig)

                VStack(spacing: 0) {
                    HStack {
                        Button {
                            showDebugGenerating = false
                            RmAsyncWorkPollCoordinator.shared.reset()
                        } label: {
                            Text(AppLanguageStore.localized("common.close"))
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.white.opacity(0.92))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.35))

                    Spacer(minLength: 0)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .onAppear {
                RmAsyncWorkPollCoordinator.shared.debugEnterFakeGeneratingState(progress: 0.65)
            }
            .onDisappear {
                RmAsyncWorkPollCoordinator.shared.reset()
            }
        }
    }

    private var collapseToggleBar: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isExpanded.toggle()
        } label: {
            HStack(spacing: 8) {
                Text("DEBUG")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(AppTheme.outlineVariant)
                if isExpanded {
                    Text("首页调试")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.onSurfaceVariant.opacity(0.85))
                }
                Image(systemName: isExpanded ? "chevron.compact.down" : "chevron.compact.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primary.opacity(0.9))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: Self.panelMaxWidth)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.surfaceContainerHigh.opacity(0.94))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AppTheme.outlineVariant.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func debugRow(title: String, trailing: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.onSurface)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text(trailing)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static func debugPlaceholderPortrait() -> UIImage {
        let size = CGSize(width: 120, height: 160)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 0.38, green: 0.22, blue: 0.48, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}

#endif
