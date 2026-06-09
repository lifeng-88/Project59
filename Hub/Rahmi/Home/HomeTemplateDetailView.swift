//
//  HomeTemplateDetailView.swift
//  Rahmi
//
//  瀑布流点击 cell 进入：拉取详情。T1 多图时主图用 `ImmersiveFeedMediaBackdrop` 双图来回扫荡（与瀑布流一致），**不传** `transAnimationCarouselURLs`，避免误走 trans 顺序轮播。
//  T2·T3 预览主图见 `HomeTemplateDetailT2T3PreviewHero`：先展示接口 `transAnimation` 首段（静图或视频解码首帧），成片预加载完成后切换为静音循环成片。
//  `/v1/version_config`：`type == 1` 与首页同源走 **Preview A 面**（霓虹底、主图卡高光、圆角 CTA）；`type == 2` 走 **B 面**（平铺底、经典胶囊按钮与简化浮层）。
//

import Photos
import SwiftUI
import UIKit

struct HomeTemplateDetailView: View {
    let gridItem: HomeGridCardItem
    /// 已选好人像图后进入全屏生成流程（含上传）
    var onUseTemplate: (HomeFeedItem, UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthSessionStore
    @EnvironmentObject private var wallet: UserWalletStore
    @EnvironmentObject private var tabRouter: AppTabRouter
    @EnvironmentObject private var versionConfig: VersionConfigStore
    @EnvironmentObject private var appLanguage: AppLanguageStore

    @AppStorage("homeUploadTipsSuppressed") private var uploadTipsSuppressed = false
    @State private var phase: LoadPhase = .loading
    @State private var likedTemplateKeys: Set<String> = []
    @State private var pickedImage: UIImage?
    @State private var showUploadTips = false
    @State private var dontShowAgainTips = false
    @State private var showLegacyPhotoPicker = false
    @State private var showPhotoPermissionAlert = false
    /// 金币不足时全屏充值套餐层（与 `HomeTemplateGenerationSheet` 一致）
    @State private var showRechargeUpsell = false

    private enum LoadPhase {
        case loading
        case failed(String)
        case loaded(LoadedDetail)
    }

    private enum LoadedDetail {
        case t1(ImageTemplate)
        case t2(DancingTemplate)
        case t3(VideoTemplate)
    }

    /// 与 `HomeView.showsHomeVariantA`、`VersionConfigStore.isPresentationVariantAUIEnabled` 同源：`type == 1` → A 面。
    private var showsTemplateDetailVariantA: Bool {
        versionConfig.isPresentationVariantAUIEnabled
    }

    private var templateDetailCardCorner: CGFloat {
        showsTemplateDetailVariantA ? 18 : 14
    }

    private let previewCTACornerA: CGFloat = 18

    private var isLocked: Bool {
        if case .locked = gridItem.bottomLeft { return true }
        return false
    }

    private var likeKey: String { gridItem.likeStateKey }
    private var isLiked: Bool { likedTemplateKeys.contains(likeKey) }

    /// 导航栏标题「预览」
    private var previewPrincipalTitle: AttributedString {
        let m = NSMutableAttributedString(string: AppLanguageStore.localized("home.template.detail.preview_title"))
        let range = NSRange(location: 0, length: m.length)
        if showsTemplateDetailVariantA {
            m.addAttribute(.kern, value: 1.6, range: range)
            m.addAttribute(.font, value: UIFont.systemFont(ofSize: 17, weight: .heavy), range: range)
        } else {
            m.addAttribute(.kern, value: 1.2, range: range)
            m.addAttribute(.font, value: UIFont.systemFont(ofSize: 16, weight: .heavy), range: range)
        }
        m.addAttribute(.foregroundColor, value: UIColor(AppTheme.primary), range: range)
        return AttributedString(m)
    }

    @ViewBuilder
    private var templateDetailPageBackground: some View {
        if showsTemplateDetailVariantA {
            previewPageChromeBackground
        } else {
            AppTheme.background
                .ignoresSafeArea()
        }
    }

    /// Preview A 面：午夜底 + 中心柔光，避免整屏平涂。
    private var previewPageChromeBackground: some View {
        ZStack {
            AppTheme.background
            RadialGradient(
                colors: [
                    AppTheme.primaryDim.opacity(0.28),
                    AppTheme.accentCyan.opacity(0.06),
                    Color.clear
                ],
                center: UnitPoint(x: 0.52, y: 0.32),
                startRadius: 20,
                endRadius: 380
            )
            LinearGradient(
                colors: [Color.black.opacity(0.22), Color.clear, Color.black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    /// Preview A 面底栏：与主内容区轻微分离，顶边霓虹细线。
    private var previewBottomActionChrome: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    AppTheme.surfaceContainer.opacity(0.72),
                    AppTheme.background.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.accentCyan.opacity(0.55),
                            AppTheme.primary.opacity(0.4),
                            AppTheme.primaryDim.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1.25)
                .padding(.horizontal, 20)
        }
    }

    private var smallPickSlotWidth: CGFloat {
        showsTemplateDetailVariantA ? 96 : 92
    }

    private var smallPickSlotHeight: CGFloat { smallPickSlotWidth * 16.0 / 9.0 }

    /// 与瀑布流 cell 同源：`loading` / `failed` 用列表带入的 `gridItem`；`loaded` 用详情构建的 `HomeFeedItem` 再合并角标。
    private var heroGridCardItem: HomeGridCardItem {
        switch phase {
        case .loaded(let detail):
            return feedItemForPreviewUI(from: detail).gridCardItemMatchingList(chrome: gridItem)
        case .loading, .failed:
            return gridItem
        }
    }

    private var detailHeroPhaseLoaded: Bool {
        if case .loaded = phase { return true }
        return false
    }

    private var heroMediaIdentityKey: String {
        switch phase {
        case .loaded(let detail):
            let feed = feedItemForPreviewUI(from: detail)
            return "loaded-\(feed.id)-\(feed.templateKind.rawValue)"
        case .loading:
            return "loading-\(gridItem.id)"
        case .failed:
            return "failed-\(gridItem.id)"
        }
    }

    @ViewBuilder
    private func heroPrimaryMedia(width w: CGFloat, height h: CGFloat) -> some View {
        switch phase {
        case .loaded(let detail):
            let feed = feedItemForPreviewUI(from: detail)
            if feed.templateKind == .t1, feed.slideshowURLs.count >= 2 {
                /// `transAnimationCarouselURLs` 非空时会优先走 `HomeImmersiveTransAnimationCarouselBackdrop`（多段轮播）。T1 预览只要与瀑布流一致的**双图扫荡**，故传空，由 `imageURLs`≥2 走 `ImmersiveFeedScanCompareBackdrop`。
                ImmersiveFeedMediaBackdrop(
                    itemId: feed.id,
                    playbackVideoURL: nil,
                    imageURLs: feed.immersiveImageURLs,
                    interval: feed.slideshowInterval,
                    width: w,
                    height: h,
                    isSwitchingActive: true,
                    stoppedPosterVideoURL: nil,
                    aspectFit: true,
                    transAnimationCarouselURLs: []
                )
            } else if feed.templateKind == .t2 || feed.templateKind == .t3 {
                HomeTemplateDetailT2T3PreviewHero(
                    itemId: feed.id,
                    placeholderMediaURL: feed.templateDetailPreviewPlaceholderURL,
                    playbackVideoURL: feed.immersivePrimaryLoopVideoURL ?? feed.playbackVideoURL,
                    fallbackImageURL: feed.imageURL ?? gridItem.imageURL,
                    width: w,
                    height: h,
                    aspectFit: true,
                    hasTemplateVoice: feed.hasTemplateVoice
                )
            } else {
                HomeGridCardSharedMediaStack(
                    item: heroGridCardItem,
                    isPlaybackActive: true,
                    onPlaybackFinished: nil,
                    fixedWidthHeight: CGSize(width: w, height: h),
                    cellAspectRatio: gridItem.aspectRatio,
                    showsBottomLeftBadge: true
                )
            }
        case .loading, .failed:
            /// T2/T3：先展示 trans 首帧占位，等详情加载后由 `HomeTemplateDetailT2T3PreviewHero` 预加载完成再叠循环成片；勿在 loading 时直接播网格视频。
            HomeGridCardSharedMediaStack(
                item: gridItem,
                isPlaybackActive: gridItem.templateKind != .t2 && gridItem.templateKind != .t3,
                onPlaybackFinished: nil,
                fixedWidthHeight: CGSize(width: w, height: h),
                cellAspectRatio: gridItem.aspectRatio,
                showsBottomLeftBadge: true
            )
        }
    }

    var body: some View {
        let _ = appLanguage.preference
        ZStack {
            templateDetailPageBackground

            VStack(spacing: 0) {
                heroMatchingGridCard
                    .padding(.horizontal, showsTemplateDetailVariantA ? 14 : 10)
                    .padding(.top, showsTemplateDetailVariantA ? 6 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)

                templateBottomBar
                    .padding(.horizontal, showsTemplateDetailVariantA ? 18 : 16)
                    .padding(.top, showsTemplateDetailVariantA ? 18 : 12)
                    .padding(.bottom, showsTemplateDetailVariantA ? 14 : 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        Group {
                            if showsTemplateDetailVariantA {
                                previewBottomActionChrome
                            } else {
                                AppTheme.background
                            }
                        }
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showUploadTips {
                HomeUploadTipsOverlay(
                    dontShowAgain: $dontShowAgainTips,
                    onClose: {
                        withAnimation(.easeOut(duration: 0.22)) { showUploadTips = false }
                    },
                    onConfirm: {
                        if dontShowAgainTips { uploadTipsSuppressed = true }
                        withAnimation(.easeOut(duration: 0.22)) { showUploadTips = false }
                        DispatchQueue.main.async { presentPhotoPickerIfAuthorized() }
                    }
                )
                .transition(.opacity)
                .zIndex(4)
            }

            LegacyImagePicker(image: $pickedImage, isPresented: $showLegacyPhotoPicker)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .zIndex(-1)

            if showRechargeUpsell {
                HomeGenerationRechargeUpsellView(
                    onClose: { showRechargeUpsell = false },
                    onExploreFullRecharge: {
                        showRechargeUpsell = false
                        tabRouter.select(.recharge)
                    }
                )
                .environmentObject(wallet)
                .environmentObject(auth)
                .environmentObject(versionConfig)
                .environmentObject(tabRouter)
                .environmentObject(appLanguage)
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        /// 首页根视图隐藏导航栏后，详情页需显式恢复，否则可能继承隐藏状态
        .rahmiToolbarVisibleNavigationBar()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BBBNavigationBackButton {
                    dismiss()
                }
            }
            ToolbarItem(placement: .principal) {
                Text(previewPrincipalTitle)
                    .font(.system(size: showsTemplateDetailVariantA ? 17 : 16, weight: .heavy))
                    .foregroundStyle(AppTheme.primary)
            }
        }
        /// 顶栏：仅金币；收藏已叠在大图右上角
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    tabRouter.select(.recharge)
                } label: {
                    if showsTemplateDetailVariantA {
                        HStack(spacing: 5) {
                            AppCoinIcon(size: 17)
                            Text(wallet.formattedCoinBalance)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(AppTheme.onSurface)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.42))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            AppTheme.accentCyan.opacity(0.55),
                                            AppTheme.primary.opacity(0.45),
                                            AppTheme.outlineVariant.opacity(0.35)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                    } else {
                        HStack(spacing: 4) {
                            AppCoinIcon(size: 18)
                            Text(wallet.formattedCoinBalance)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppTheme.onSurface)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.black.opacity(0.38))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppTheme.outlineVariant.opacity(0.4), lineWidth: 1)
                        )
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .rahmiNavigationBarBackground(AppTheme.background)
        .task {
            await loadDetail()
        }
        .onAppear {
            likedTemplateKeys = LocalFavoriteTemplateStore.load(userId: auth.userId)
            #if DEBUG
            if gridItem.id == Self.previewSeedTemplateDetailId, pickedImage == nil {
                pickedImage = Self.makePreviewSeedUserPickImage()
            }
            #endif
        }
        .onChange(of: auth.userId) { _ in
            likedTemplateKeys = LocalFavoriteTemplateStore.load(userId: auth.userId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .localFavoriteTemplateStoreDidChange)) { _ in
            likedTemplateKeys = LocalFavoriteTemplateStore.load(userId: auth.userId)
        }
        .alert(AppLanguageStore.localized("home.template.photo_permission.title"), isPresented: $showPhotoPermissionAlert) {
            Button(AppLanguageStore.localized("common.cancel"), role: .cancel) {}
            Button(AppLanguageStore.localized("home.template.photo_permission.open_settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(AppLanguageStore.localized("home.template.photo_permission.message"))
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: showUploadTips)
        .rahmiRefreshOnAppLanguage()
    }

    private var templateDetailPickSlotCorner: CGFloat {
        showsTemplateDetailVariantA ? 14 : 12
    }

    private var smallUserPhotoPickSlot: some View {
        Button(action: { requestPhotoPickerAfterTipsIfNeeded() }) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let pickedImage {
                        Image(uiImage: pickedImage)
                            .resizable()
                            .scaledToFill()
                    } else if showsTemplateDetailVariantA {
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.72),
                                    AppTheme.surfaceContainerHigh.opacity(0.55)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Rectangle()
                                .fill(.ultraThinMaterial.opacity(0.35))
                            LinearGradient(
                                colors: [
                                    AppTheme.accentCyan.opacity(0.22),
                                    Color.clear,
                                    AppTheme.primary.opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "person.crop.rectangle.badge.plus")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white.opacity(0.95), AppTheme.onSurfaceVariant.opacity(0.9)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    } else {
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.58),
                                    Color.black.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Rectangle()
                                .fill(.ultraThinMaterial.opacity(0.48))
                            LinearGradient(
                                colors: [
                                    AppTheme.accentCyan.opacity(0.16),
                                    Color.clear,
                                    AppTheme.primary.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "person.crop.rectangle.badge.plus")
                                .font(.system(size: 26))
                                .foregroundStyle(Color.white.opacity(0.92))
                        }
                    }
                }
                .frame(width: smallPickSlotWidth, height: smallPickSlotHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: templateDetailPickSlotCorner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: templateDetailPickSlotCorner, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: showsTemplateDetailVariantA
                                    ? [
                                        Color.white.opacity(0.38),
                                        AppTheme.accentCyan.opacity(0.28),
                                        AppTheme.outlineVariant.opacity(0.45)
                                    ]
                                    : [
                                        Color.white.opacity(0.28),
                                        AppTheme.outlineVariant.opacity(0.35)
                                    ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: showsTemplateDetailVariantA ? 1.5 : 1.25
                        )
                )

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: showsTemplateDetailVariantA ? 12 : 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: showsTemplateDetailVariantA ? 30 : 28, height: showsTemplateDetailVariantA ? 30 : 28)
                    .background(
                        Group {
                            if showsTemplateDetailVariantA {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.primary, AppTheme.primaryDim],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                            } else {
                                Circle()
                                    .fill(AppTheme.primary)
                                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            }
                        }
                    )
                    .shadow(
                        color: showsTemplateDetailVariantA ? AppTheme.primary.opacity(0.45) : Color.clear,
                        radius: showsTemplateDetailVariantA ? 6 : 0,
                        y: showsTemplateDetailVariantA ? 2 : 0
                    )
                    .offset(x: showsTemplateDetailVariantA ? -11 : -10, y: showsTemplateDetailVariantA ? -11 : -10)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppLanguageStore.localized("home.template.sheet.pick_photo"))
        .shadow(
            color: .black.opacity(showsTemplateDetailVariantA ? 0.55 : 0.4),
            radius: showsTemplateDetailVariantA ? 14 : 10,
            y: showsTemplateDetailVariantA ? 6 : 4
        )
    }

    private func requestPhotoPickerAfterTipsIfNeeded() {
        if uploadTipsSuppressed {
            presentPhotoPickerIfAuthorized()
        } else {
            dontShowAgainTips = false
            showUploadTips = true
        }
    }

    private func presentPhotoPickerIfAuthorized() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            showLegacyPhotoPicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    switch newStatus {
                    case .authorized, .limited:
                        showLegacyPhotoPicker = true
                    case .denied, .restricted:
                        showPhotoPermissionAlert = true
                    default:
                        break
                    }
                }
            }
        case .denied, .restricted:
            showPhotoPermissionAlert = true
        @unknown default:
            showLegacyPhotoPicker = true
        }
    }

    // MARK: - 主图区（T1 多图：`ImmersiveFeedMediaBackdrop` 双图扫荡；T1 单图 / 加载失败：同瀑布流 `HomeGridCardSharedMediaStack`；T2·T3：`ImmersiveFeedMediaBackdrop` trans 轮播）

    private var heroMatchingGridCard: some View {
        GeometryReader { outer in
            let w = outer.size.width
            let h = outer.size.height
            ZStack {
                heroPrimaryMedia(width: w, height: h)
                    .animation(.easeInOut(duration: 0.45), value: detailHeroPhaseLoaded)
                    .id(heroMediaIdentityKey)
                /// 列表 cell 心形在右下；此处与人像选区同侧，改为右上避免重叠。
                .overlay(alignment: .topTrailing) {
                    detailHeartButton
                        .padding(12)
                }

                if case .loaded = phase, !isLocked {
                    VStack {
                        Spacer(minLength: 0)
                        HStack {
                            Spacer(minLength: 0)
                            smallUserPhotoPickSlot
                                .padding(12)
                        }
                    }
                }
            }
            .frame(width: w, height: h)
        }
        /// 避免 `GeometryReader` 在栈布局首帧高度为 0，导致主图区不可见。
        .aspectRatio(gridItem.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: templateDetailCardCorner, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: templateDetailCardCorner, style: .continuous)
                .fill(AppTheme.surfaceContainer)
        )
        .clipShape(RoundedRectangle(cornerRadius: templateDetailCardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: templateDetailCardCorner, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: showsTemplateDetailVariantA
                            ? [
                                Color.white.opacity(0.16),
                                AppTheme.accentCyan.opacity(0.22),
                                AppTheme.primary.opacity(0.12),
                                AppTheme.outlineVariant.opacity(0.2)
                            ]
                            : [Color.white.opacity(0.1), AppTheme.outlineVariant.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: showsTemplateDetailVariantA ? 1.25 : 1
                )
        )
        .shadow(color: showsTemplateDetailVariantA ? AppTheme.primary.opacity(0.14) : Color.clear, radius: showsTemplateDetailVariantA ? 28 : 0, y: showsTemplateDetailVariantA ? 10 : 0)
        .shadow(color: .black.opacity(showsTemplateDetailVariantA ? 0.55 : 0.45), radius: showsTemplateDetailVariantA ? 20 : 14, y: showsTemplateDetailVariantA ? 12 : 6)
    }

    private var formattedCoinDisplay: String {
        let n = displayCoinValue
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private var displayCoinValue: Int {
        if let c = resolvedCoinsFromDetail { return c }
        if case .coins(let n) = gridItem.bottomLeft { return n }
        return 0
    }

    private var resolvedCoinsFromDetail: Int? {
        switch phase {
        case .loaded(let d):
            switch d {
            case .t1(let t): return Self.parseGold(t.consumedGold)
            case .t2(let t): return Self.parseGold(t.consumedGold)
            case .t3(let t): return Self.parseGold(t.consumedGold)
            }
        case .loading, .failed:
            return nil
        }
    }

    private var detailHeartButton: some View {
        Button(action: { toggleLike() }) {
            if showsTemplateDetailVariantA {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isLiked ? AppTheme.primary : Color.white.opacity(0.92))
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.52))
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.22),
                                        AppTheme.primary.opacity(isLiked ? 0.55 : 0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
            } else {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 16))
                    .foregroundStyle(isLiked ? AppTheme.primary : .white)
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleLike() {
        let willLike = !likedTemplateKeys.contains(likeKey)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if willLike {
            likedTemplateKeys.insert(likeKey)
        } else {
            likedTemplateKeys.remove(likeKey)
        }
        LocalFavoriteTemplateStore.save(likedTemplateKeys, userId: auth.userId)
    }

    @ViewBuilder
    private func templateDetailGenerateButtonChromeA(feed: HomeFeedItem, flashActive: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(AppLanguageStore.localized("home.template.detail.generate"))
                    .font(.system(size: 17, weight: .heavy))
                    .tracking(0.8)
                Rectangle()
                    .fill(Color.white.opacity(0.32))
                    .frame(width: 1, height: 22)
                HStack(spacing: 6) {
                    AppCoinIcon(size: 19)
                    if flashActive,
                       let original = feed.originalConsumedCoins,
                       original > feed.consumedCoins {
                        HStack(spacing: 4) {
                            Text("\(original)")
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .strikethrough(true)
                                .foregroundStyle(Color.white.opacity(0.68))
                            Text("\(feed.consumedCoins)")
                                .font(.system(size: 16, weight: .heavy))
                                .monospacedDigit()
                        }
                    } else {
                        Text("\(feed.consumedCoins)")
                            .font(.system(size: 17, weight: .heavy))
                            .monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .foregroundStyle(.white)
            .background(
                Group {
                    if pickedImage == nil {
                        LinearGradient(
                            colors: [
                                AppTheme.surfaceContainerHighest.opacity(0.95),
                                AppTheme.surfaceContainer.opacity(0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        AppTheme.premiumButtonGradient
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: previewCTACornerA, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: previewCTACornerA, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: pickedImage == nil
                                ? [AppTheme.outlineVariant.opacity(0.45), Color.white.opacity(0.06)]
                                : [Color.white.opacity(0.42), AppTheme.accentCyan.opacity(0.35), AppTheme.primary.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: pickedImage == nil ? 1 : 1.25
                    )
            )
            .shadow(color: pickedImage == nil ? Color.clear : AppTheme.accentCyan.opacity(0.2), radius: 16, y: 4)
            .shadow(color: pickedImage == nil ? Color.clear : Color.black.opacity(0.38), radius: 14, y: 8)

            if flashActive, let pct = HomeFlashSalePresentation.discountPercent(feed) {
                Text(String(format: AppLanguageStore.localized("home.immersive.discount_corner_format"), Int64(pct)))
                    .font(.system(size: 11, weight: .black))
                    .italic()
                    .foregroundStyle(Color.black.opacity(0.88))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color(red: 250 / 255, green: 204 / 255, blue: 21 / 255))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.32), radius: 6, x: 0, y: 3)
                    .rotationEffect(.degrees(-5))
                    .offset(x: 10, y: -14)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func templateDetailGenerateButtonChromeB(feed: HomeFeedItem, flashActive: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 18, weight: .semibold))
                Text(AppLanguageStore.localized("home.template.detail.generate"))
                    .font(.system(size: 17, weight: .heavy))
                Rectangle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 1, height: 18)
                HStack(spacing: 6) {
                    AppCoinIcon(size: 18)
                    if flashActive,
                       let original = feed.originalConsumedCoins,
                       original > feed.consumedCoins {
                        HStack(spacing: 4) {
                            Text("\(original)")
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .strikethrough(true)
                                .foregroundStyle(Color.white.opacity(0.65))
                            Text("\(feed.consumedCoins)")
                                .font(.system(size: 15, weight: .bold))
                                .monospacedDigit()
                        }
                    } else {
                        Text("\(feed.consumedCoins)")
                            .font(.system(size: 16, weight: .bold))
                            .monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                Group {
                    if pickedImage == nil {
                        AppTheme.surfaceContainerHighest
                    } else {
                        AppTheme.premiumButtonGradient
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Group {
                    if pickedImage != nil {
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    }
                }
            )
            .shadow(color: pickedImage == nil ? Color.clear : Color.black.opacity(0.25), radius: 4, y: 2)

            if flashActive, let pct = HomeFlashSalePresentation.discountPercent(feed) {
                Text(String(format: AppLanguageStore.localized("home.immersive.discount_corner_format"), Int64(pct)))
                    .font(.system(size: 10, weight: .black))
                    .italic()
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(red: 250 / 255, green: 204 / 255, blue: 21 / 255))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .rotationEffect(.degrees(-4))
                    .offset(x: 8, y: -12)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func templateDetailGenerateButton(feed: HomeFeedItem, flashActive: Bool, variantA: Bool) -> some View {
        Button(action: {
            guard let img = pickedImage else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            let cost = feed.consumedCoins
            if cost > 0, wallet.coinBalance < cost {
                showRechargeUpsell = true
                return
            }
            onUseTemplate(feed, img)
        }) {
            if variantA {
                templateDetailGenerateButtonChromeA(feed: feed, flashActive: flashActive)
            } else {
                templateDetailGenerateButtonChromeB(feed: feed, flashActive: flashActive)
            }
        }
        .buttonStyle(.plain)
        .disabled(pickedImage == nil)
    }

    // MARK: - 文案与 CTA

    @ViewBuilder
    private var templateBottomBar: some View {
        switch phase {
        case .loading:
            HStack {
                Spacer()
                ProgressView()
                    .tint(AppTheme.primary)
                Spacer()
            }
            .padding(.vertical, 8)
        case .failed(let msg):
            Text(msg)
                .font(.footnote)
                .foregroundStyle(Color.red.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(AppLanguageStore.localized("common.retry")) {
                Task { await loadDetail() }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
        case .loaded(let detail):
            if isLocked {
                Label(AppLanguageStore.localized("home.template.detail.unavailable"), systemImage: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            } else {
                let feed = feedItemForPreviewUI(from: detail)
                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    let flashActive = HomeFlashSalePresentation.isFlashSaleActive(feed, now: context.date)
                    if showsTemplateDetailVariantA {
                        VStack(alignment: .leading, spacing: 14) {
                            if let countdown = HomeFlashSalePresentation.countdownText(feed, now: context.date) {
                                HomeFlashSaleCountdownBar(countdown: countdown)
                                    .allowsHitTesting(false)
                            }
                            templateDetailGenerateButton(
                                feed: feed,
                                flashActive: flashActive,
                                variantA: true
                            )
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            if let countdown = HomeFlashSalePresentation.countdownText(feed, now: context.date) {
                                HomeFlashSaleCountdownBar(countdown: countdown)
                                    .allowsHitTesting(false)
                                    .padding(.bottom, -6)
                                    .zIndex(1)
                            }
                            templateDetailGenerateButton(
                                feed: feed,
                                flashActive: flashActive,
                                variantA: false
                            )
                        }
                    }
                }
            }
        }
    }

    private func feedItem(from detail: LoadedDetail) -> HomeFeedItem {
        switch detail {
        case .t1(let t): return HomeFeedItem(imageTemplate: t)
        case .t2(let t): return HomeFeedItem(dancingTemplate: t)
        case .t3(let t): return HomeFeedItem(videoTemplate: t)
        }
    }

    /// 接口详情 → `HomeFeedItem`；DEBUG 下可按 `HomeFeedDebugSimulators.simulateDiscountInTemplateDetailPreview` 走与沉浸式相同的限时折扣模拟（倒计时档位、划线原价等）。
    private func feedItemForPreviewUI(from detail: LoadedDetail) -> HomeFeedItem {
        let raw = feedItem(from: detail)
        #if DEBUG
        guard HomeFeedDebugSimulators.simulateDiscountInTemplateDetailPreview else { return raw }
        var hasher = Hasher()
        hasher.combine(gridItem.id)
        return raw.simulatingDiscountForDebug(seed: hasher.finalize())
        #else
        return raw
        #endif
    }

    private func loadDetail() async {
        await MainActor.run { phase = .loading }
        #if DEBUG
        if gridItem.id == Self.previewSeedTemplateDetailId {
            await MainActor.run {
                phase = .loaded(.t1(Self.makePreviewSeedImageTemplate()))
            }
            return
        }
        #endif
        let result: Result<LoadedDetail, AppError>
        switch gridItem.templateKind {
        case .t1:
            let r = await RmCatalogWorkRepository.shared.getImageTemplateDetail(tid: gridItem.id)
            result = r.map { .t1($0) }
        case .t2:
            let r = await RmCatalogWorkRepository.shared.getDancingTemplateDetail(tid: gridItem.id)
            result = r.map { .t2($0) }
        case .t3:
            let r = await RmCatalogWorkRepository.shared.getVideoTemplateDetail(tid: gridItem.id)
            result = r.map { .t3($0) }
        }
        await MainActor.run {
            switch result {
            case .success(let d):
                phase = .loaded(d)
            case .failure(let err):
                phase = .failed(err.userMessage)
            }
        }
    }

    private static func parseGold(_ s: String) -> Int {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if let v = Int(t) { return v }
        if let d = Double(t) { return Int(d.rounded()) }
        return 0
    }
}

#if DEBUG

// MARK: - SwiftUI Preview · 模板详情（离线种子；`version_config.type` 1=A 面 / 2=B 面）

extension HomeTemplateDetailView {
    static let previewSeedTemplateDetailId = "rahmi-swiftui-preview-template-detail"

    fileprivate static let previewSeedBeforeURL =
        "https://lh3.googleusercontent.com/aida-public/AB6AXuCTmfxFmNZ8N_-A0kKPK5QBGEDKYT-cFiY_3a9cSHtanseBUNpDtWHBu9YcL7tD09AcGOHAps_dcqPFppFTHmdUf4yzBqbLyKQ-_5V0nWBhLuDcKUxwzpV403NrkVV5FKxtiHLcPPbCA4t2KeM-tpqLxckQqI5n-Qp42Kd0a0M3iBtq4bKzGjbuv6IcvZTcg5OAreWsaL4UJ4h4qwGXxkXCGLOsp8UlJDUFuhSchrFrZdUteJjxSLVVw2ySZRsKBHF6deBQU-JS-JkN"

    fileprivate static let previewSeedAfterURL =
        "https://lh3.googleusercontent.com/aida-public/AB6AXuBXKz2V6Ea0kW-GqCpETP3ghfIRqxMkr5zTGdNljWy_vKvd578ah3e3H2JoX8dM0wyzVolGTOegz3pxJWNXyvQ6fGCd9uGjn554qeqE7ZlIojv3pcM0w5sWMQbXBYliGCH9i0hI0Yf79QnhgCcXdQBiywMwvXpvG9qSuMEQWghiazEBkrgrBm1naWZV6PeA6-9-6440QNG2R5dQ_rBE7IQ2ZF-hDFB4f64gyr0BenQMjMEgcw9qf_C1H4Jkz4x8PnlWEXf_NhuuSUJZ"

    static var previewSeedGridItem: HomeGridCardItem {
        let u1 = URL(string: previewSeedBeforeURL)!
        let u2 = URL(string: previewSeedAfterURL)!
        return HomeGridCardItem(
            id: previewSeedTemplateDetailId,
            imageURL: u1,
            previewVideoURL: nil,
            gridSlideshowURLs: [u1, u2],
            gridTransAnimationVideoURL: nil,
            gridVideoTransAnimationImageURLs: [],
            gridCarouselTimelineURLs: [],
            gridSlideshowInterval: 2.4,
            topTag: nil,
            bottomLeft: .coins(1),
            aspectRatio: 9 / 16,
            templateKind: .t1,
            transAnimation: "2400",
            hasTemplateVoice: false
        )
    }

    static func makePreviewSeedImageTemplate() -> ImageTemplate {
        let ends = Int(Date().timeIntervalSince1970) + (90 * 60 + 13)
        return ImageTemplate(
            id: previewSeedTemplateDetailId,
            title: "Preview",
            beforePics: [previewSeedBeforeURL, previewSeedAfterURL],
            beforePicsType: [0, 0],
            afterPic: previewSeedAfterURL,
            changeBackground: false,
            transAnimation: "2400",
            consumedGold: "1",
            isNew: nil,
            isHot: nil,
            hasAudio: nil,
            discountEndsAt: "\(ends)",
            originalConsumedGold: "2"
        )
    }

    static func makePreviewSeedUserPickImage() -> UIImage {
        let r = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 160))
        return r.image { ctx in
            UIColor.systemPurple.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: 120, height: 160)))
        }
    }
}

private struct HomeTemplateDetailViewPreviewHost: View {
    @StateObject private var wallet = UserWalletStore()
    @StateObject private var auth = AuthSessionStore()
    @StateObject private var tabRouter = AppTabRouter()
    @StateObject private var versionConfig = VersionConfigStore()
    @StateObject private var appLanguage = AppLanguageStore()

    var body: some View {
        NavigationView {
            HomeTemplateDetailView(
                gridItem: HomeTemplateDetailView.previewSeedGridItem,
                onUseTemplate: { _, _ in }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environmentObject(wallet)
        .environmentObject(auth)
        .environmentObject(tabRouter)
        .environmentObject(versionConfig)
        .environmentObject(appLanguage)
        .onAppear {
            versionConfig.debugSetPresentationType(1)
            wallet.applyServerBalanceString("362")
        }
        .preferredColorScheme(.dark)
    }
}

private struct HomeTemplateDetailViewPreviewHostVariantB: View {
    @StateObject private var wallet = UserWalletStore()
    @StateObject private var auth = AuthSessionStore()
    @StateObject private var tabRouter = AppTabRouter()
    @StateObject private var versionConfig = VersionConfigStore()
    @StateObject private var appLanguage = AppLanguageStore()

    var body: some View {
        NavigationView {
            HomeTemplateDetailView(
                gridItem: HomeTemplateDetailView.previewSeedGridItem,
                onUseTemplate: { _, _ in }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environmentObject(wallet)
        .environmentObject(auth)
        .environmentObject(tabRouter)
        .environmentObject(versionConfig)
        .environmentObject(appLanguage)
        .onAppear {
            versionConfig.debugSetPresentationType(2)
            wallet.applyServerBalanceString("362")
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("模板详情 Preview · A 面 (type=1)") {
    HomeTemplateDetailViewPreviewHost()
}

#Preview("模板详情 Preview · B 面 (type=2)") {
    HomeTemplateDetailViewPreviewHostVariantB()
}

#endif

// MARK: - T2/T3 预览主图：trans 首段 → 成片循环

/// 先展示 `transAnimation` **首段**占位（图片用 `HomeCachedImage`；视频段用解码首帧）；`immersivePrimaryLoopVideoURL` 预加载完成后再叠 `HomeImmersiveVideoBackdrop` 静音循环（与沉浸式列表同源）。
private struct HomeTemplateDetailT2T3PreviewHero: View {
    let itemId: String
    /// 优先接口 `transAnimation` 字段首段，见 `HomeFeedItem.templateDetailPreviewPlaceholderURL`
    let placeholderMediaURL: URL?
    let playbackVideoURL: URL?
    let fallbackImageURL: URL?
    let width: CGFloat
    let height: CGFloat
    var aspectFit: Bool = true
    var hasTemplateVoice: Bool = false

    @State private var showLoopingPlayback = false

    var body: some View {
        ZStack {
            Color.black
            if showLoopingPlayback, let pv = playbackVideoURL {
                HomeImmersiveVideoBackdrop(
                    remoteURL: pv,
                    width: width,
                    height: height,
                    hasTemplateVoice: hasTemplateVoice,
                    externalPlaybackMuted: nil
                )
                    .id("\(itemId)-detail-loop-\(pv.absoluteString)")
                    .transition(.opacity)
            } else {
                firstTransPlaceholder
                    .transition(.opacity)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .animation(.easeInOut(duration: 0.38), value: showLoopingPlayback)
        .task(id: "\(itemId)-\(playbackVideoURL?.absoluteString ?? "nil")") {
            await MainActor.run { showLoopingPlayback = false }
            guard let pv = playbackVideoURL else { return }
            let s = pv.absoluteString
            await VideoCacheManager.shared.preloadVideo(videoURL: s, priority: .userInitiated, isCurrentDisplay: true)
            await MainActor.run {
                showLoopingPlayback = true
            }
        }
    }

    @ViewBuilder
    private var firstTransPlaceholder: some View {
        if let u = placeholderMediaURL {
            if HomeImmersiveMediaURL.isVideo(u) {
                HomeGridTransAnimationVideoPosterView(videoURL: u)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                HomeCachedImage(
                    url: u,
                    priority: .userInitiated,
                    aspectFit: aspectFit,
                    showsLoadingIndicator: true
                )
                .frame(width: width, height: height)
                .clipped()
            }
        } else if let u = fallbackImageURL {
            HomeCachedImage(
                url: u,
                priority: .userInitiated,
                aspectFit: aspectFit,
                showsLoadingIndicator: true
            )
            .frame(width: width, height: height)
            .clipped()
        } else if let pv = playbackVideoURL {
            HomeGridTransAnimationVideoPosterView(videoURL: pv)
                .frame(width: width, height: height)
                .clipped()
        } else {
            AppTheme.surfaceContainer
        }
    }
}
