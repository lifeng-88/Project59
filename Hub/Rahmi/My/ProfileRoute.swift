//
//  ProfileRoute.swift
//  Rahmi
//

import SwiftUI

enum ProfileRoute: Hashable {
    case creations
    case rechargeRecord
    case likes
    case settings
    case userAgreement
    case privacy
    case feedback
    /// 远程推送 `feedback_reply`：直达历史列表，可选滚动到 `feedback_id` 对应条目
    case feedbackHistory(focusFeedbackId: Int64?)
    /// 远程推送 `generation_success`：直达截图中的 Generation Success 页。
    /// `PushGenerationSuccessDestinationView` 内部自行 `GET /v1/tasks/{taskId}` 拉详情。
    case generationSuccess(taskId: String)
    /// 远程推送 `generation_failure`：直达指定任务的 Creation 详情页，
    /// 不经过「我的创作」列表（导航栈：`MyProfileView` → `CreationDetailView`）。
    /// `CreationDetailView(taskId:)` 内部自行 `GET /v1/tasks/{taskId}` 拉详情，
    /// 即使服务端 404 / 500 也能在页面内显示错误 + 重试，而不是静默中止跳转。
    case creationDetail(taskId: String)
}

struct ProfileRouteDestination: View {
    let route: ProfileRoute
    @EnvironmentObject private var wallet: UserWalletStore

    var body: some View {
        switch route {
        case .creations:
            MyCreationsView()
        case .rechargeRecord:
            RechargeRecordListView()
        case .likes:
            MyLikesView()
        case .settings:
            ProfileSettingsView()
        case .userAgreement:
            LegalH5DocumentView(url: ResBaseURL.termsAndConditionsURL, titleLocalizationKey: "legal.user_agreement")
        case .privacy:
            LegalH5DocumentView(url: ResBaseURL.privacyPolicyURL, titleLocalizationKey: "legal.privacy")
        case .feedback:
            FeedbackCenterView()
        case .feedbackHistory(let focusId):
            FeedbackHistoryView(focusFeedbackId: focusId)
        case .generationSuccess(let taskId):
            PushGenerationSuccessDestinationView(taskId: taskId)
        case .creationDetail(let taskId):
            CreationDetailView(taskId: taskId)
        }
    }
}

private struct PushGenerationSuccessDestinationView: View {
    let taskId: String

    @State private var item: TaskListItem?
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let item {
                GenerationSuccessView(item: item)
            } else if loading {
                loadingView
            } else if let errorMessage {
                errorView(errorMessage)
            } else {
                loadingView
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: taskId) {
            await loadTask()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.primary)
            Text(AppLanguageStore.localized("common.loading"))
                .font(.subheadline)
                .foregroundStyle(AppTheme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.onSurfaceVariant)
            Text(AppLanguageStore.localizedUserFacingAPIError(message))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .padding(.horizontal, 32)
            Button {
                Task { await loadTask() }
            } label: {
                Text(AppLanguageStore.localized("common.retry"))
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadTask() async {
        let trimmed = taskId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await MainActor.run {
            loading = true
            errorMessage = nil
        }
        let result = await RmAsyncRenderJobWireTransport.getTask(taskId: trimmed)
        await MainActor.run {
            loading = false
            switch result {
            case .success(let resp):
                item = TaskListItem(
                    taskId: resp.taskId,
                    taskType: resp.taskType,
                    tid: resp.tid,
                    totalStage: nil,
                    currentStage: nil,
                    status: resp.status,
                    userParams: resp.userParams,
                    resultUrl: resp.resultUrl,
                    createTs: resp.createTs,
                    execTs: resp.execTs,
                    finishTs: resp.finishTs,
                    waitSeconds: resp.waitSeconds,
                    execSeconds: resp.execSeconds,
                    readStatus: nil,
                    consumedGold: nil
                )
            case .failure(let err):
                errorMessage = err.userMessage
                print("📲 [PushGenerationSuccessDestinationView] 拉单条任务失败 task=\(trimmed): \(err.userMessage)")
            }
        }
    }
}
