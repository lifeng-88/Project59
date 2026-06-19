//
//  RmAsyncWorkPollCoordinator.swift
//  glam
//
//  Created by Dev on 2026/1/19.
//

import Foundation
import Combine

/// 任务状态服务（使用 WebSocket 接收实时推送）
@MainActor
class RmAsyncWorkPollCoordinator: ObservableObject {
    static let shared = RmAsyncWorkPollCoordinator()
    
    @Published var taskStatus: TaskStatus = .pending
    @Published var taskResponse: GetTaskResponse?
    @Published var progress: Double = 0.0 // 0.0 - 1.0
    @Published var rank: Int? // 排队位置
    @Published var waitTime: String? // 等待时间
    @Published var errorMessage: String? // 错误消息

    /// 是否有进行中的生成（排队或生成中），供首页横幅等展示
    var isGenerationInProgress: Bool {
        isMonitoring && (taskStatus == .pending || taskStatus == .running)
    }
    
    private var isMonitoring: Bool = false
    private var taskId: String?
    private var startTime: Date?
    private var pendingStartTime: Date?
    private var runningStartTime: Date?
    
    private let webSocketService = RmRealtimePushSession.shared
    
    private init() {
        // 设置 WebSocket 回调
        webSocketService.onTaskProgress = { [weak self] taskId, status, progressValue in
            Task { @MainActor [weak self] in
                self?.handleTaskProgress(taskId: taskId, status: status, progress: progressValue)
            }
        }
    }
    
    /// 开始监控任务状态（通过 WebSocket）
    /// - Parameter taskId: 任务ID
    func startPolling(taskId: String) {
        print("🚀 [RmAsyncWorkPollCoordinator] ========== Start Polling ==========")
        print("🚀 [RmAsyncWorkPollCoordinator] taskId: \(taskId)")
        print("🚀 [RmAsyncWorkPollCoordinator] Current isMonitoring: \(isMonitoring)")
        
        if isMonitoring, self.taskId == taskId {
            print("⚠️ [RmAsyncWorkPollCoordinator] Already monitoring same taskId, skipping")
            return
        }
        if isMonitoring {
            print("⚠️ [RmAsyncWorkPollCoordinator] New task while monitoring — stop previous session")
            stopPolling()
        }

        self.taskId = taskId
        self.isMonitoring = true
        self.errorMessage = nil
        self.startTime = Date()
        self.pendingStartTime = Date()
        self.runningStartTime = nil
        
        // 设置初始状态为 pending，并显示默认等待时间
        self.taskStatus = .pending
        self.progress = 0.0
        self.waitTime = "~3 min"
        
        print("🚀 [RmAsyncWorkPollCoordinator] Initial state set - status: .pending, progress: 0.0, waitTime: ~3 min")
        
        // 连接 WebSocket（如果尚未连接）
        Task {
            print("🚀 [RmAsyncWorkPollCoordinator] Getting access token...")
            let token = await RmHTTPGatewayActor.shared.getAccessToken()
            if let token = token {
                print("🚀 [RmAsyncWorkPollCoordinator] Token obtained, length: \(token.count) characters")
                print("🚀 [RmAsyncWorkPollCoordinator] Connecting WebSocket...")
                webSocketService.connect(token: token)
            } else {
                print("❌ [RmAsyncWorkPollCoordinator] No access token available for WebSocket connection")
            }
        }
        
        // 注意：不再设置超时错误
        // 等待和生成界面中不存在超时错误，只有服务器返回错误时才显示错误
        
        print("🚀 [RmAsyncWorkPollCoordinator] Start polling completed")
    }
    
    /// 停止监控
    func stopPolling() {
        isMonitoring = false
        // 注意：不断开 WebSocket，因为可能还有其他任务在使用
    }
    
    /// 处理任务进度更新（来自 WebSocket）
    private func handleTaskProgress(taskId: Int64, status: Int32, progress: Int32) {
        print("📊 [RmAsyncWorkPollCoordinator] ========== Handle Task Progress ==========")
        print("📊 [RmAsyncWorkPollCoordinator] Received - taskId: \(taskId), status: \(status), progress: \(progress)")
        print("📊 [RmAsyncWorkPollCoordinator] Current monitoring taskId: \(self.taskId ?? "nil")")
        print("📊 [RmAsyncWorkPollCoordinator] Current isMonitoring: \(isMonitoring)")
        
        // 检查是否是当前监控的任务
        guard let currentTaskId = self.taskId else {
            print("⚠️ [RmAsyncWorkPollCoordinator] No current taskId set, ignoring progress update")
            return
        }
        
        guard let currentTaskIdInt = Int64(currentTaskId) else {
            print("⚠️ [RmAsyncWorkPollCoordinator] Cannot convert currentTaskId to Int64: \(currentTaskId)")
            return
        }
        
        guard currentTaskIdInt == taskId else {
            print("⚠️ [RmAsyncWorkPollCoordinator] TaskId mismatch - received: \(taskId), current: \(currentTaskIdInt)")
            return
        }
        
        print("✅ [RmAsyncWorkPollCoordinator] TaskId matches, processing progress update")
        
        // 转换状态
        guard let newStatus = TaskStatus(rawValue: status) else {
            print("❌ [RmAsyncWorkPollCoordinator] Invalid status value: \(status) (valid: 0-3)")
            return
        }
        
        let oldStatus = self.taskStatus
        print("📊 [RmAsyncWorkPollCoordinator] Status change: \(oldStatus) (raw: \(oldStatus.rawValue)) -> \(newStatus) (raw: \(newStatus.rawValue))")
        
        // 根据状态更新相关字段（在更新 taskStatus 之前）
        if newStatus == .failed {
            print("❌ [RmAsyncWorkPollCoordinator] Status is FAILED, task failed (from WebSocket)")
            // 先设置默认错误消息，确保在状态更新时就有错误消息
            self.errorMessage = AppLanguageStore.localized("task.error.failed_default")
            self.isMonitoring = false
            // 获取更详细的错误信息（如果有）
            Task {
                await fetchFullTaskInfo()
            }
            // 更新任务状态为失败
            self.taskStatus = .failed
        } else if newStatus == .success {
            print("✅ [RmAsyncWorkPollCoordinator] Status is SUCCESS, task completed")
            self.progress = 1.0
            self.isMonitoring = false
            print("📊 [RmAsyncWorkPollCoordinator] Fetching full task info for resultUrl...")
            // 先获取完整任务信息（包括 resultUrl），验证 resultUrl 后再更新状态
            // 这样可以避免在 resultUrl 为空时显示成功界面
            Task {
                await fetchFullTaskInfo()
                print("📊 [RmAsyncWorkPollCoordinator] Full task info fetched, resultUrl: \(self.taskResponse?.resultUrl ?? "nil")")
                // 检查 resultUrl 是否为空
                if let resultUrl = self.taskResponse?.resultUrl, !resultUrl.isEmpty {
                    // resultUrl 有效，设置为成功状态
                    print("✅ [RmAsyncWorkPollCoordinator] resultUrl is valid, setting status to success")
                    self.taskStatus = .success
                    // 刷新余额
                    await BalanceManager.shared.refreshBalance()
                } else {
                    // resultUrl 为空或获取失败，确保状态为失败
                    if self.taskStatus != .failed {
                        print("⚠️ [RmAsyncWorkPollCoordinator] resultUrl is empty but status is not failed, setting to failed")
                        self.errorMessage = AppLanguageStore.localized("task.error.result_missing")
                        self.taskStatus = .failed
                    } else {
                        print("❌ [RmAsyncWorkPollCoordinator] resultUrl is empty, task status already changed to failed")
                    }
                }
            }
            // 注意：这里不立即更新 taskStatus，等待 fetchFullTaskInfo 完成后再更新
            // 如果 resultUrl 为空，fetchFullTaskInfo 会将状态设置为 .failed
        } else {
            // 其他状态（pending, running）立即更新
            self.taskStatus = newStatus
            
            // 更新进度和其他状态
            if newStatus == .running {
                print("📊 [RmAsyncWorkPollCoordinator] Status is RUNNING, updating progress")
                // 生成中：使用 progress 值（0-100）转换为 0.0-1.0
                let progressValue = min(1.0, Double(progress) / 100.0)
                self.progress = progressValue
                print("📊 [RmAsyncWorkPollCoordinator] Progress updated: \(progress)% -> \(progressValue)")
                
                if runningStartTime == nil {
                    runningStartTime = Date()
                    print("📊 [RmAsyncWorkPollCoordinator] Running start time set: \(runningStartTime!)")
                }
            } else if newStatus == .pending {
                print("⏳ [RmAsyncWorkPollCoordinator] Status is PENDING, updating wait time")
                // 排队中：显示默认等待时间
                self.waitTime = "~3 min"
                self.progress = 0.0
            }
        }
        
        print("📊 [RmAsyncWorkPollCoordinator] Progress update completed")
    }
    
    /// 获取完整任务信息（可选，用于获取 resultUrl 等详细信息）
    func fetchFullTaskInfo() async {
        guard let taskId = taskId else { return }
        
        let result = await RmAsyncRenderJobWireTransport.getTask(taskId: taskId)
        switch result {
        case .success(let response):
            self.taskResponse = response
            // 如果任务完成，检查 resultUrl
            if response.taskStatus == .success {
                // 检查 resultUrl 是否为空
                if let resultUrl = response.resultUrl, !resultUrl.isEmpty {
                    // resultUrl 有效，正常处理
                    print("✅ [RmAsyncWorkPollCoordinator] Task completed with resultUrl: \(resultUrl)")
                } else {
                    // resultUrl 为空，视为错误
                    print("❌ [RmAsyncWorkPollCoordinator] Task status is SUCCESS but resultUrl is empty")
                    errorMessage = AppLanguageStore.localized("task.error.result_missing")
                    // 将状态改为失败，以便显示错误提示
                    self.taskStatus = .failed
                }
            } else if response.taskStatus == .failed {
                // 任务失败，设置错误消息
                // 如果服务器没有返回具体错误消息，使用默认消息
                errorMessage = AppLanguageStore.localized("task.error.failed_default")
                // 确保状态为失败
                self.taskStatus = .failed
            }
        case .failure(let error):
            print("⚠️ [RmAsyncWorkPollCoordinator] Failed to fetch full task info: \(error)")
            // 如果是网络错误，设置错误消息
            if case .networkError(let message) = error {
                errorMessage = AppLanguageStore.localizedFormat(
                    "task.error.network_with_reason",
                    AppLanguageStore.localizedUserFacingAPIError(message)
                )
            } else if case .serverError(_, let message) = error {
                let resolved = message.isEmpty
                    ? AppLanguageStore.localized("task.error.server_default")
                    : AppLanguageStore.localizedUserFacingAPIError(message)
                errorMessage = resolved
            } else {
                errorMessage = AppLanguageStore.localizedUserFacingAPIError(error.userMessage)
            }
            // 将状态改为失败，以便显示错误提示
            self.taskStatus = .failed
        }
    }
    
    /// 重置状态
    func reset() {
        stopPolling()
        taskStatus = .pending
        taskResponse = nil
        progress = 0.0
        rank = nil
        waitTime = nil
        errorMessage = nil
        taskId = nil
        startTime = nil
        pendingStartTime = nil
        runningStartTime = nil
    }

    #if DEBUG
    /// 仅供 DEBUG UI：模拟「生成中」环形进度，不启动 WebSocket；离开调试全屏后请 `reset()`。
    func debugEnterFakeGeneratingState(progress: Double = 0.65) {
        stopPolling()
        taskId = "rahmi_debug_sim"
        isMonitoring = true
        taskStatus = .running
        self.progress = min(1, max(0, progress))
        waitTime = nil
        errorMessage = nil
        taskResponse = nil
    }
    #endif
}
