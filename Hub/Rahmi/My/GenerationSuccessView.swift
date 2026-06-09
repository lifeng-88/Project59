//
//  GenerationSuccessView.swift
//  Rahmi
//
//  成功任务详情：大图、信息条、收藏、Reroll、下载、反馈。
//  **`/v1/version_config` `type == 1`** 时走 **A 面**（霓虹装饰背景、信息条左起收藏、薰衣草下载钮等）；否则为经典 **B 面**。
//

import AVKit
import Photos
import SwiftUI
import UIKit

struct GenerationSuccessView: View {
    let item: TaskListItem
    /// 关闭成功页后回调（例如刷新「我的创作」列表）；Reroll 现改为跳转首页生成流程，仍会调用以便列表更新
    var onRerollSuccess: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.rahmiGenerationSuccessHostDismiss) private var hostDismiss: (() -> Void)?
    @EnvironmentObject private var auth: AuthSessionStore
    @EnvironmentObject private var wallet: UserWalletStore
    @EnvironmentObject private var appLanguage: AppLanguageStore
    @EnvironmentObject private var tabRouter: AppTabRouter
    @EnvironmentObject private var versionConfig: VersionConfigStore

    @State private var likedTemplateKeys: Set<String> = []
    @State private var isRerolling = false
    @State private var isDownloading = false
    @State private var showFeedback = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    /// 相册权限被拒后用户再次点「下载」的次数；第 2 次起在弹窗中提供「去设置」
    @State private var photoSavePermissionDeniedAttempts = 0
    /// 当前 Alert 是否在「无法保存（相册权限）」场景下展示「打开系统设置」按钮（第二次及以后）
    @State private var alertShowsOpenSettingsButton = false
    @State private var videoPlayer: AVPlayer?

    init(item: TaskListItem, onRerollSuccess: (() -> Void)? = nil) {
        self.item = item
        self.onRerollSuccess = onRerollSuccess
    }

    private static func parseTaskIdInt64(_ raw: String) -> Int64? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return Int64(t)
    }

    private var rawResult: String {
        item.resultUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var resolvedMediaURL: URL? {
        GenerationSuccessMediaURL.resolve(rawResult)
    }

    private var isVideo: Bool {
        let lower = rawResult.lowercased()
        return lower.hasSuffix(".mp4") || lower.hasSuffix(".mov") || lower.hasSuffix(".m4v")
    }

    private var templateKind: TemplateResourceKind? {
        switch item.taskType {
        case 1: return .t1
        case 2: return .t2
        case 3: return .t3
        default: return nil
        }
    }

    private var likeKey: String? {
        guard let k = templateKind, !item.tid.isEmpty else { return nil }
        return "\(k.rawValue):\(item.tid)"
    }

    private var typeBarLabel: String {
        switch item.taskType {
        case 1: return AppLanguageStore.localized("kind.image")
        case 2: return AppLanguageStore.localized("kind.dance")
        case 3: return AppLanguageStore.localized("kind.video")
        default: return AppLanguageStore.localized("kind.media")
        }
    }

    /// 与模板详情主图、首页网格卡片一致：竖版 9:16，宽度随屏幕自适应。
    private let mainMediaAspectRatio: CGFloat = 9 / 16

    private var successGradientBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 18 / 255, green: 10 / 255, blue: 42 / 255),
                AppTheme.background,
                Color(red: 28 / 255, green: 14 / 255, blue: 52 / 255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// A 面：深底 + 霓虹光斑 + 波浪线装饰（叠于经典渐变之上）
    private var generationSuccessVariantABackground: some View {
        ZStack {
            successGradientBackground
            GenerationSuccessVariantANeonDecoration()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    var body: some View {
        let _ = appLanguage.preference
        Group {
            if versionConfig.isPresentationVariantAUIEnabled {
                generationSuccessVariantAShell
            } else {
                generationSuccessClassicShell
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                BBBTrackedText.text(AppLanguageStore.localized("generation.success.title"), size: 13, weight: .heavy, tracking: 1.0, color: Color.white)
            }
        }
        .rahmiToolbarVisibleNavigationBar()
        .rahmiNavigationBarBackground(Color.black.opacity(0.2))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BBBNavigationBackButton(showsLocalizedTitle: false) {
                    if let hostDismiss {
                        hostDismiss()
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            likedTemplateKeys = LocalFavoriteTemplateStore.load(userId: auth.userId)
            if isVideo, let u = resolvedMediaURL {
                let key = u.absoluteString
                Task {
                    await VideoCacheManager.shared.preloadVideo(videoURL: key, priority: .userInitiated, isCurrentDisplay: true)
                    let playURL = await VideoCacheManager.shared.getVideoURL(for: key) ?? u
                    await MainActor.run {
                        videoPlayer = AVPlayer(url: playURL)
                    }
                }
            }
        }
        .onDisappear {
            videoPlayer?.pause()
            videoPlayer = nil
        }
        .sheet(isPresented: $showFeedback) {
            NavigationView {
                FeedbackCenterView(
                    feedbackPageEnterSource: "template_quality",
                    feedbackSubmitTaskId: Self.parseTaskIdInt64(item.taskId),
                    feedbackSubmitActualSpentAmount: item.consumedGold
                )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(AppLanguageStore.localized("common.close")) { showFeedback = false }
                        }
                    }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .alert(alertTitle, isPresented: $showAlert) {
            if alertShowsOpenSettingsButton {
                Button(AppLanguageStore.localized("home.template.photo_permission.open_settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            Button(AppLanguageStore.localized("common.ok"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    /// B 面（经典布局）
    private var generationSuccessClassicShell: some View {
        ZStack {
            successGradientBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    mainMediaBlock
                        .padding(.horizontal, 16)

                    infoActionBar
                        .padding(.horizontal, 16)

                    bottomActions
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
            }
        }
    }

    /// A 面：装饰背景 + 信息条「收藏 | 缩略图 | 类型 | Reroll」+ 薰衣草下载钮 / 霓虹描边反馈钮
    private var generationSuccessVariantAShell: some View {
        ZStack {
            generationSuccessVariantABackground

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 18) {
                    mainMediaBlock
                        .padding(.horizontal, 16)

                    infoActionBarVariantA
                        .padding(.horizontal, 16)

                    bottomActionsVariantA
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private var mainMediaBlock: some View {
        if let url = resolvedMediaURL {
            if isVideo {
                VideoPlayer(player: videoPlayer)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(mainMediaAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppTheme.outlineVariant.opacity(0.25), lineWidth: 1)
                    )
            } else {
                /// 先限宽再定比例：`HomeCachedImage` 内 `UIImage` 固有尺寸极大，否则会撑宽整条 `ScrollView` 内容，出现底部条右移、左侧大块留白。
                HomeCachedImage(url: url, priority: .userInitiated, aspectFit: true)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(mainMediaAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppTheme.outlineVariant.opacity(0.25), lineWidth: 1)
                    )
            }
        }
    }

    private var infoActionBar: some View {
        HStack(spacing: 12) {
            thumbnailTiny
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                BBBTrackedText.text(AppLanguageStore.localized("generation.success.type_label"), size: 9, weight: .semibold, tracking: 0.6, color: AppTheme.outlineVariant)
                Text(typeBarLabel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white)
            }

            Spacer(minLength: 8)

            if let key = likeKey {
                Button {
                    toggleFavorite(likeKey: key)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: likedTemplateKeys.contains(key) ? "heart.fill" : "heart")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(
                                likedTemplateKeys.contains(key)
                                    ? AppTheme.primary
                                    : AppTheme.onSurfaceVariant
                            )
                    }
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { await reroll() }
            } label: {
                HStack(spacing: 6) {
                    if isRerolling {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .bold))
                    }
                    BBBTrackedText.text(AppLanguageStore.localized("generation.success.reroll"), size: 11, weight: .heavy, tracking: 0.8)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.premiumButtonGradient)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isRerolling || (item.userParams?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.surfaceContainer.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.outlineVariant.opacity(0.2), lineWidth: 1)
        )
    }

    /// A 面：收藏在左 → 缩略图 → 类型文案 → Reroll（描边胶囊）；底条半透明 + 霓虹渐变描边
    private var infoActionBarVariantA: some View {
        HStack(spacing: 12) {
            if let key = likeKey {
                Button {
                    toggleFavorite(likeKey: key)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Image(systemName: likedTemplateKeys.contains(key) ? "heart.fill" : "heart")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(
                                likedTemplateKeys.contains(key)
                                    ? AppTheme.primary
                                    : Color.white.opacity(0.9)
                            )
                    }
                }
                .buttonStyle(.plain)
            }

            thumbnailTiny
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                BBBTrackedText.text(AppLanguageStore.localized("generation.success.type_label"), size: 9, weight: .semibold, tracking: 0.6, color: Color.white.opacity(0.55))
                Text(typeBarLabel)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color.white)
            }

            Spacer(minLength: 8)

            Button {
                Task { await reroll() }
            } label: {
                HStack(spacing: 6) {
                    if isRerolling {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .bold))
                    }
                    BBBTrackedText.text(AppLanguageStore.localized("generation.success.reroll"), size: 11, weight: .heavy, tracking: 0.8)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppTheme.accentCyan.opacity(0.95),
                                    AppTheme.primary,
                                    AppTheme.primaryDim.opacity(0.9)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.35
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isRerolling || (item.userParams?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppTheme.accentCyan.opacity(0.45),
                            Color.white.opacity(0.12),
                            AppTheme.primary.opacity(0.5)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private var thumbnailTiny: some View {
        if let url = resolvedMediaURL {
            if isVideo {
                ZStack {
                    AppTheme.surfaceContainerHighest
                    Image(systemName: "film.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.primary)
                }
                .frame(width: 52, height: 52)
            } else {
                HomeCachedImage(url: url, priority: .utility, aspectFit: true)
                    .frame(width: 52, height: 52)
                    .clipped()
            }
        } else {
            AppTheme.surfaceContainerHighest
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button {
                Task { await saveToPhotos() }
            } label: {
                HStack(spacing: 8) {
                    if isDownloading {
                        ProgressView()
                            .tint(Color(red: 42 / 255, green: 18 / 255, blue: 72 / 255))
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    BBBTrackedText.text(AppLanguageStore.localized("generation.success.download"), size: 13, weight: .heavy, tracking: 0.6)
                }
                .foregroundStyle(Color(red: 42 / 255, green: 18 / 255, blue: 72 / 255))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.primary.opacity(0.92))
                )
            }
            .buttonStyle(.plain)
            .disabled(isDownloading || resolvedMediaURL == nil)

            Button {
                showFeedback = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                    BBBTrackedText.text(AppLanguageStore.localized("generation.success.feedback"), size: 13, weight: .heavy, tracking: 0.6)
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.primary.opacity(0.55), lineWidth: 1.2)
                )
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// A 面：薰衣草渐变「下载」+ 深色霓虹描边「反馈」
    private var bottomActionsVariantA: some View {
        let downloadTextColor = Color(red: 42 / 255, green: 18 / 255, blue: 72 / 255)
        return HStack(spacing: 12) {
            Button {
                Task { await saveToPhotos() }
            } label: {
                HStack(spacing: 8) {
                    if isDownloading {
                        ProgressView()
                            .tint(downloadTextColor)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    BBBTrackedText.text(AppLanguageStore.localized("generation.success.download"), size: 13, weight: .heavy, tracking: 0.6)
                }
                .foregroundStyle(downloadTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 228 / 255, green: 206 / 255, blue: 252 / 255),
                                    AppTheme.primary.opacity(0.72),
                                    Color(red: 188 / 255, green: 148 / 255, blue: 236 / 255)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.32), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDownloading || resolvedMediaURL == nil)

            Button {
                showFeedback = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 15, weight: .semibold))
                    BBBTrackedText.text(AppLanguageStore.localized("generation.success.feedback"), size: 13, weight: .heavy, tracking: 0.6)
                }
                .foregroundStyle(AppTheme.accentCyan.opacity(0.96))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.premiumButtonGradient, lineWidth: 1.35)
                )
                .shadow(color: AppTheme.primary.opacity(0.25), radius: 14, y: 5)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func toggleFavorite(likeKey: String) {
        let willLike = !likedTemplateKeys.contains(likeKey)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if willLike {
            likedTemplateKeys.insert(likeKey)
        } else {
            likedTemplateKeys.remove(likeKey)
        }
        LocalFavoriteTemplateStore.save(likedTemplateKeys, userId: auth.userId)
    }

    /// 重新走该模板的完整生成流程（首页 `HomeTemplateGenerationSheet`：选图 → 上传 → 建单），与主站生成入口一致。
    private func reroll() async {
        let tid = item.tid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tid.isEmpty else {
            await MainActor.run {
                alertShowsOpenSettingsButton = false
                alertTitle = AppLanguageStore.localized("common.tip")
                alertMessage = AppLanguageStore.localized("generation.success.reroll.template_load_failed")
                showAlert = true
            }
            return
        }
        guard auth.isAuthenticated else {
            await MainActor.run {
                alertShowsOpenSettingsButton = false
                alertTitle = AppLanguageStore.localized("home.alert.login.title")
                alertMessage = AppLanguageStore.localized("home.alert.login.message")
                showAlert = true
            }
            return
        }

        await MainActor.run { isRerolling = true }
        let feedItem = await loadHomeFeedItemForReroll()
        await MainActor.run { isRerolling = false }

        guard let feedItem else {
            await MainActor.run {
                alertShowsOpenSettingsButton = false
                alertTitle = AppLanguageStore.localized("common.tip")
                alertMessage = AppLanguageStore.localized("generation.success.reroll.template_load_failed")
                showAlert = true
            }
            return
        }

        await MainActor.run {
            dismiss()
        }
        onRerollSuccess?()
        tabRouter.select(.home)
        let payload = feedItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(
                name: .homeRequestPrimaryGenerate,
                object: payload,
                userInfo: ["browseOtherReturnTabRaw": AppTab.my.rawValue]
            )
        }
    }

    private func loadHomeFeedItemForReroll() async -> HomeFeedItem? {
        let tid = item.tid.trimmingCharacters(in: .whitespacesAndNewlines)
        switch item.taskType {
        case 1:
            let r = await RmCatalogWorkRepository.shared.getImageTemplateDetail(tid: tid)
            if case .success(let t) = r { return HomeFeedItem(imageTemplate: t) }
        case 2:
            let r = await RmCatalogWorkRepository.shared.getDancingTemplateDetail(tid: tid)
            if case .success(let t) = r { return HomeFeedItem(dancingTemplate: t) }
        case 3:
            let r = await RmCatalogWorkRepository.shared.getVideoTemplateDetail(tid: tid)
            if case .success(let t) = r { return HomeFeedItem(videoTemplate: t) }
        default:
            break
        }
        return nil
    }

    private func saveToPhotos() async {
        guard let url = resolvedMediaURL else { return }
        let ok = await requestAddOnlyPhotoAccess()
        guard ok else {
            await MainActor.run {
                photoSavePermissionDeniedAttempts += 1
                alertShowsOpenSettingsButton = photoSavePermissionDeniedAttempts >= 2
                alertTitle = AppLanguageStore.localized("generation.success.save.denied.title")
                alertMessage = AppLanguageStore.localized("generation.success.save.denied.message")
                showAlert = true
            }
            return
        }

        await MainActor.run {
            photoSavePermissionDeniedAttempts = 0
            isDownloading = true
        }
        do {
            if isVideo {
                let (fileURL, isTemporaryCopy) = try await resolveVideoFileForSaving(from: url)
                try await saveVideoFileToLibrary(at: fileURL)
                if isTemporaryCopy {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            } else {
                let key = url.absoluteString
                var image = await ImageCacheManager.shared.getImage(for: key)
                if image == nil {
                    await ImageCacheManager.shared.preloadImage(urlString: key, priority: .userInitiated)
                    image = await ImageCacheManager.shared.getImage(for: key)
                }
                guard let image else {
                    throw NSError(
                        domain: "rahmi",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: AppLanguageStore.localized("generation.success.save.error.invalid_image")]
                    )
                }
                try await saveImageToLibrary(image)
            }
            await MainActor.run {
                isDownloading = false
                photoSavePermissionDeniedAttempts = 0
                alertShowsOpenSettingsButton = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                alertTitle = AppLanguageStore.localized("generation.success.save.ok.title")
                alertMessage = AppLanguageStore.localized("generation.success.save.ok.message")
                showAlert = true
            }
        } catch {
            await MainActor.run {
                isDownloading = false
                alertShowsOpenSettingsButton = false
                alertTitle = AppLanguageStore.localized("generation.success.save.error.title")
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func requestAddOnlyPhotoAccess() async -> Bool {
        await withCheckedContinuation { cont in
            if #available(iOS 14, *) {
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    cont.resume(returning: status == .authorized || status == .limited)
                }
            } else {
                PHPhotoLibrary.requestAuthorization { status in
                    cont.resume(returning: status == .authorized)
                }
            }
        }
    }

    private func saveImageToLibrary(_ image: UIImage) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    /// 优先使用 `VideoCacheManager` 已下载的本地文件；否则下载到临时目录。返回 `(文件 URL, 是否为临时文件需删除)`。
    private func resolveVideoFileForSaving(from url: URL) async throws -> (URL, Bool) {
        let key = url.absoluteString
        if let cached = await VideoCacheManager.shared.getVideoURL(for: key) {
            return (cached, false)
        }
        await VideoCacheManager.shared.preloadVideo(videoURL: key, priority: .userInitiated, isCurrentDisplay: true)
        if let cached = await VideoCacheManager.shared.getVideoURL(for: key) {
            return (cached, false)
        }
        let tmp = try await downloadToTemporaryFile(from: url)
        return (tmp, true)
    }

    private func downloadToTemporaryFile(from url: URL) async throws -> URL {
        let (localURL, _) = try await URLSession.shared.download(from: url)
        let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: localURL, to: dest)
        return dest
    }

    private func saveVideoFileToLibrary(at fileURL: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
        }
    }
}

// MARK: - 生成成功 A 面背景装饰（霓虹光斑 + 波浪线）

private struct GenerationSuccessVariantANeonDecoration: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .blur(radius: 50)
                    .offset(x: w * 0.34, y: -h * 0.05)
                Circle()
                    .fill(AppTheme.accentCyan.opacity(0.16))
                    .frame(width: 230, height: 230)
                    .blur(radius: 58)
                    .offset(x: -w * 0.36, y: h * 0.4)

                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.primary.opacity(0.65), AppTheme.accentCyan.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .position(x: w * 0.9, y: h * 0.11)
                    .opacity(0.55)

                Image(systemName: "sparkles")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accentCyan.opacity(0.55), AppTheme.primary.opacity(0.45)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .position(x: w * 0.1, y: h * 0.8)
                    .opacity(0.48)

                Canvas { context, size in
                    let width = size.width
                    let height = size.height
                    for i in 0..<5 {
                        var path = Path()
                        let baseY = height * (0.1 + CGFloat(i) * 0.15)
                        path.move(to: CGPoint(x: 0, y: baseY))
                        var x: CGFloat = 0
                        while x <= width {
                            let y = baseY + sin((x / 40) + CGFloat(i) * 0.7) * (5 + CGFloat(i % 3))
                            path.addLine(to: CGPoint(x: x, y: y))
                            x += 7
                        }
                        context.stroke(
                            path,
                            with: .color(AppTheme.primary.opacity(0.09 - Double(i) * 0.012)),
                            lineWidth: 1.15
                        )
                    }
                    for i in 0..<4 {
                        var path = Path()
                        let baseY = height * (0.18 + CGFloat(i) * 0.19)
                        path.move(to: CGPoint(x: 0, y: baseY))
                        var x: CGFloat = 0
                        while x <= width {
                            let y = baseY + cos((x / 36) + CGFloat(i) * 0.5) * 5.5
                            path.addLine(to: CGPoint(x: x, y: y))
                            x += 7
                        }
                        context.stroke(
                            path,
                            with: .color(AppTheme.accentCyan.opacity(0.075 - Double(i) * 0.01)),
                            lineWidth: 1
                        )
                    }
                }
                .blendMode(.plusLighter)
            }
        }
    }
}

// MARK: - Media URL（与 `MyCreationsView` 中 `TaskResultMediaURL` 一致）

/// 宿主（如 DEBUG `fullScreenCover`）可注入：返回时优先执行，避免仅包一层 `NavigationView` 时 `Environment.dismiss` 无法收起全屏。
private struct RahmiGenerationSuccessHostDismissKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var rahmiGenerationSuccessHostDismiss: (() -> Void)? {
        get { self[RahmiGenerationSuccessHostDismissKey.self] }
        set { self[RahmiGenerationSuccessHostDismissKey.self] = newValue }
    }
}

private enum GenerationSuccessMediaURL {
    static func resolve(_ path: String) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        let base = ResBaseURL.effective
        if trimmed.hasPrefix("/") {
            return URL(string: trimmed, relativeTo: URL(string: base))?.absoluteURL
        }
        let sep = base.hasSuffix("/") ? "" : "/"
        return URL(string: base + sep + trimmed)
    }
}
