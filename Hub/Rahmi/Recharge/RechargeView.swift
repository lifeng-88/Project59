//
//  RechargeView.swift
//  Rahmi
//
//  参考: refined_recharge_layout_v2 + 支付、记录、结果反馈
//

import SwiftUI
import UIKit

/// 单次 `GeometryReader` 同时上报 ScrollView 顶/底安全区，避免双背景重复测量
private struct RechargeScrollSafeArea: Equatable {
    var top: CGFloat = 0
    var bottom: CGFloat = 0
}

private struct RechargeScrollSafeAreaKey: PreferenceKey {
    static var defaultValue = RechargeScrollSafeArea()
    static func reduce(value: inout RechargeScrollSafeArea, nextValue: () -> RechargeScrollSafeArea) {
        let n = nextValue()
        value.top = n.top
        value.bottom = n.bottom
    }
}

/// 充值页：与 App Icon / `AppTheme` 同系的深底 + 青粉紫霓虹；金黄仍用于余额与金币强调。
private enum RechargeDesign {
    static let background = Color(red: 12 / 255, green: 10 / 255, blue: 38 / 255)
    static let purple = AppTheme.primaryDim
    static let pink = AppTheme.primary
    static let gold = Color(red: 234 / 255, green: 179 / 255, blue: 8 / 255)

    static let ctaGradient = LinearGradient(
        colors: [AppTheme.accentCyan, AppTheme.primary, AppTheme.primaryDim],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardFill = Color.white.opacity(0.055)
    static let cardFillElevated = Color.white.opacity(0.09)
    static let balancePillStroke = Color.white.opacity(0.12)

    static let ctaTitleDark = Color(red: 18 / 255, green: 12 / 255, blue: 28 / 255)
}

/// 充值页圆角：列表行与主按钮（`continuous`）
private enum RechargeLayout {
    static let listRowCorner: CGFloat = 24
    static let primaryButtonCorner: CGFloat = 22
    /// 卡片左右内边距（与 `packageListCell` 一致）
    static let packageRowHorizontalPadding: CGFloat = 16
    /// 套餐行固定总高（圆角矩形主体）；角标为 overlay，仍依赖首行顶距防裁切
    static let packageCardFixedHeight: CGFloat = 88
    /// 固定高度内统一竖向内边距（角标浮在顶外，由首卡 `scrollTopClearance` 与顶 padding 共同避让）
    static let packageCardInnerVerticalPadding: CGFloat = 12
    /// 角标胶囊近似总高度（字号 + 上下 padding）
    static let badgePillHeight: CGFloat = 22
    /// 角标 `.offset(y: -8)` 与胶囊半高之和：仅加在列表**首行**顶侧，避免首条卡片角标被 ScrollView 裁切
    static let scrollTopClearanceForBadgeOverflow: CGFloat = badgePillHeight / 2 + 8
    /// 与主文案行高对齐即可，略小于旧版 48 以压低整卡高度
    static let coinIconDiameter: CGFloat = 44
    static let listRowSpacing: CGFloat = 10
}

private enum RechargeListRowHighlight {
    case none
    case mostPopular
    case bestValue

    static func resolve(index: Int, count: Int) -> RechargeListRowHighlight {
        guard count >= 2 else { return .none }
        if index == count - 1 { return .bestValue }
        /// 第二项为「最受欢迎」（与默认选中一致）；`count == 2` 时末项已由上一行占为 BEST VALUE
        if count >= 3 && index == 1 { return .mostPopular }
        return .none
    }
}

/// 充值 A 面套餐行：青紫轻 glow；B 面保持原紫粉强 glow
private struct RechargePackageRowShadowModifier: ViewModifier {
    let variantA: Bool
    let featured: Bool

    func body(content: Content) -> some View {
        Group {
            if variantA {
                if featured {
                    content
                        .shadow(color: AppTheme.accentCyan.opacity(0.32), radius: 14, y: 4)
                        .shadow(color: AppTheme.primary.opacity(0.18), radius: 10, y: 3)
                } else {
                    content
                }
            } else if featured {
                content
                    .shadow(color: RechargeDesign.purple.opacity(0.5), radius: 20, y: 5)
                    .shadow(color: RechargeDesign.pink.opacity(0.2), radius: 12, y: 3)
            } else {
                content
            }
        }
    }
}

struct RechargeView: View {
    @EnvironmentObject private var wallet: UserWalletStore
    @EnvironmentObject private var auth: AuthSessionStore
    @EnvironmentObject private var versionConfig: VersionConfigStore
    @EnvironmentObject private var appLanguage: AppLanguageStore
    @EnvironmentObject private var tabRouter: AppTabRouter
    @Environment(\.scenePhase) private var scenePhase

    @State private var packages: [RechargePackageModel] = []
    /// 与 `packages` 对应的服务端套餐，用于 IAP 下单与 `StoreKit` 商品 ID
    @State private var domainPackages: [Package] = []
    @State private var isLoadingPackages = true
    @State private var packagesError: String?
    @State private var selectedId: String?
    @State private var checkoutPackage: RechargePackageModel?
    @State private var paymentOutcome: RechargePaymentOutcome?
    @State private var isPurchasing = false
    /// 外链支付：查询 `payment_status` 中（图1 按钮或回前台自动查）
    @State private var isQueryingBrowserPayment = false
    /// 由 `ScrollView` 背景 `GeometryReader` 上报，用于底/顶 padding；勿用外层 `GeometryReader` 包住 `ScrollView`，否则顶安全区常为 0，内容易顶到导航栏下
    @State private var scrollBottomSafeInset: CGFloat = 0
    @State private var scrollTopSafeInset: CGFloat = 0

    private var savedCardsBinding: Binding<[SavedPaymentCard]> {
        Binding(
            get: { wallet.savedCards },
            set: { wallet.savedCards = $0 }
        )
    }

    private var selectedPackage: RechargePackageModel? {
        packages.first { $0.id == selectedId }
    }

    /// 充值 A 面顶区与套餐样式；Hub 扩展模式下不展示，直链 IAP / 支付 Sheet 仍读 `rechargePresentationType`。
    private var showsRechargeVariantA: Bool {
        versionConfig.isPresentationVariantAUIEnabled
    }

    /// 默认选中第二个套餐（与「MOST POPULAR」角标一致）；仅一条时选首条
    private func defaultSelectedPackageId() -> String? {
        guard !packages.isEmpty else { return nil }
        if packages.count >= 2 { return packages[1].id }
        return packages[0].id
    }

    /// 滚动区底边距：基础间距 + 底部安全区（含 `MainTabView.safeAreaInset` 中 TabBar 与 Home Indicator 占位）。`safeBottom` 来自背景测量，避免用外层 `GeometryReader` 包裹 `ScrollView`。
    private func rechargeScrollBottomInset(safeBottom: CGFloat) -> CGFloat {
        let base: CGFloat = 16
        if safeBottom >= 1 { return base + safeBottom }
        return base + MainTabBarMetrics.estimatedContentHeight
    }

    /// 顶距：主滚动区贴导航栏下缘；测量顶安全区 + 2pt 发丝缝（首条角标额外顶距见列表首行 `.padding(.top, …)`）
    private func rechargeScrollTopPadding(measuredTop: CGFloat) -> CGFloat {
        max(0, measuredTop) + 2
    }

    var body: some View {
        let _ = appLanguage.preference
        NavigationView {
            ZStack(alignment: .top) {
                backgroundLayer

                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        rechargeListBody
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .rahmiRefreshOnAppLanguage()
                .rahmiScrollIndicatorsHidden()
                .rahmiScrollBounceBasedOnSize()
                .rahmiListScrollContentHidden()
                .rahmiScrollClipDisabledIfAvailable()
                .refreshable {
                    await loadPackages()
                }
                .padding(.horizontal, 16)
                .padding(.top, rechargeScrollTopPadding(measuredTop: scrollTopSafeInset))
                .padding(.bottom, rechargeScrollBottomInset(safeBottom: scrollBottomSafeInset))
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: RechargeScrollSafeAreaKey.self,
                            value: RechargeScrollSafeArea(
                                top: proxy.safeAreaInsets.top,
                                bottom: proxy.safeAreaInsets.bottom
                            )
                        )
                    }
                )
                .onPreferenceChange(RechargeScrollSafeAreaKey.self) { area in
                    scrollTopSafeInset = area.top
                    scrollBottomSafeInset = area.bottom
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(RechargeDesign.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .rahmiNavigationBarBackground(RechargeDesign.background)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    RechargePageLeadingTitle()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        AppCoinIcon(size: 16)
                        Text(wallet.formattedCoinBalance)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(RechargeDesign.gold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(red: 18 / 255, green: 18 / 255, blue: 28 / 255).opacity(0.94))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(RechargeDesign.balancePillStroke, lineWidth: 1)
                    )
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            Task {
                await RmClientTelemetryOutbox.shared.enqueue(
                    eventType: "recharge_page_enter",
                    templateId: "",
                    taskId: nil,
                    ts: nil,
                    extra: ["source": "recharge_tab"]
                )
            }
        }
        .task {
            await versionConfig.refresh()
            await loadPackages()
        }
        .onChange(of: packages.map(\.id)) { _ in
            if selectedId == nil || packages.first(where: { $0.id == selectedId }) == nil {
                selectedId = defaultSelectedPackageId()
            }
            applyPendingRechargeAppleProductSelection()
        }
        .onChange(of: domainPackages.map(\.id)) { _ in
            applyPendingRechargeAppleProductSelection()
        }
        .onChange(of: tabRouter.pendingRechargeAppleProductId) { _ in
            applyPendingRechargeAppleProductSelection()
        }
        .onChange(of: tabRouter.pushOfferPaymentChannelRequest) { _ in
            guard tabRouter.pushOfferPaymentChannelRequest != nil else { return }
            tabRouter.consumePushOfferPaymentChannelRequest()
            applyPendingRechargeAppleProductSelection()
            guard let pkg = selectedPackage else { return }
            Task {
                await versionConfig.refresh()
                let mode = await MainActor.run { versionConfig.rechargePresentationType }
                if mode == 1 {
                    await completePurchaseDirectIAP(package: pkg)
                } else {
                    await presentPaymentSelectionOrDirectAppleIfOnly(package: pkg)
                }
            }
        }
        .sheet(item: $checkoutPackage) { pkg in
            RechargePaymentSelectionView(
                package: pkg,
                cards: savedCardsBinding,
                isPurchasing: $isPurchasing,
                onPay: { payChannel in await completePurchase(package: pkg, payChannel: payChannel) },
                onDismiss: {
                    if !isPurchasing { checkoutPackage = nil }
                }
            )
            .rahmiSheetLargeIfAvailable()
        }
        .overlay {
            if let outcome = paymentOutcome {
                RechargeResultOverlay(
                    outcome: outcome,
                    usesVariantAPresentation: showsRechargeVariantA,
                    onDismiss: { paymentOutcome = nil },
                    onOpenedPaymentPageOK: {
                        await queryBrowserRedirectPaymentIfNeeded(isUserInitiated: true)
                    },
                    isQueryingBrowserPayment: isQueryingBrowserPayment
                )
                .zIndex(5000)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await queryBrowserRedirectPaymentIfNeeded(isUserInitiated: false) }
            }
        }
    }

    /// 浏览器重定向支付：回前台自动查一次；图1 点「好」为手动查。成功则关图1并展示成功弹窗。
    private func queryBrowserRedirectPaymentIfNeeded(isUserInitiated: Bool) async {
        let snapshot = await MainActor.run { paymentOutcome }
        guard case .openedPaymentPage(_, let orderId, let package, let payChannelId) = snapshot else { return }

        let busy = await MainActor.run { isQueryingBrowserPayment }
        if busy { return }

        await MainActor.run { isQueryingBrowserPayment = true }
        let result = await RmPurchaseLedgerRepository.shared.getOrderPaymentStatus(orderId: orderId)
        switch result {
        case .failure(let err):
            await MainActor.run {
                isQueryingBrowserPayment = false
                if isUserInitiated {
                    paymentOutcome = .failed(message: AppLanguageStore.localizedUserFacingAPIError(err.userMessage))
                }
            }
            await RechargeBehaviorEvents.enqueueRedirectPayFail(
                orderId: orderId,
                packageId: package.packageId,
                payChannelId: payChannelId,
                amountCents: package.discountPriceCents,
                reason: "get_status_failed"
            )
        case .success(let resp):
            let raw = resp.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let paid = raw == "success" || raw == "paid" || raw == "completed"
            if paid {
                let fromApi = resp.goldAmount.map { Int($0) } ?? 0
                let coins = fromApi > 0 ? fromApi : package.totalCoins
                await MainActor.run { isQueryingBrowserPayment = false }
                await RechargeBehaviorEvents.enqueueRedirectPaySuccess(
                    orderId: orderId,
                    packageId: package.packageId,
                    payChannelId: payChannelId,
                    amountCents: package.discountPriceCents
                )
                await finalizeRechargeSuccessUI(
                    package: package,
                    coinsAddedForRecord: coins,
                    skipServerBalanceSync: false
                )
            } else if raw == "pending" || raw == "processing" {
                await MainActor.run {
                    isQueryingBrowserPayment = false
                    if isUserInitiated {
                        paymentOutcome = .failed(message: AppLanguageStore.localized("recharge.browser_pay.still_pending"))
                    }
                }
                if isUserInitiated {
                    await RechargeBehaviorEvents.enqueueRedirectPayFail(
                        orderId: orderId,
                        packageId: package.packageId,
                        payChannelId: payChannelId,
                        amountCents: package.discountPriceCents,
                        reason: resp.message ?? "pending"
                    )
                }
            } else {
                let message = AppLanguageStore.localizedUserFacingAPIError(
                    resp.message ?? AppLanguageStore.localized("recharge.error.payment_incomplete")
                )
                await MainActor.run {
                    isQueryingBrowserPayment = false
                    paymentOutcome = .failed(message: message)
                }
                await RechargeBehaviorEvents.enqueueRedirectPayFail(
                    orderId: orderId,
                    packageId: package.packageId,
                    payChannelId: payChannelId,
                    amountCents: package.discountPriceCents,
                    reason: resp.message ?? "unknown_status"
                )
            }
        }
    }

    /// 支付成功后：追加流水、弹出成功弹窗。默认再拉一次 `/gold`；IAP 或已写入 `response.balance` 时传 `skipServerBalanceSync: true` 避免重复请求、加快回调。
    private func finalizeRechargeSuccessUI(
        package: RechargePackageModel,
        coinsAddedForRecord: Int,
        skipServerBalanceSync: Bool = false
    ) async {
        if !skipServerBalanceSync, let uid = auth.userId {
            await wallet.syncCoinBalanceFromServer(userId: uid)
        }
        await MainActor.run {
            wallet.appendRechargeRecordOnly(package: package, coinsAdded: coinsAddedForRecord)
            paymentOutcome = .success(
                totalCoins: package.totalCoins,
                bonusCoins: package.bonus,
                newBalanceFormatted: wallet.formattedCoinBalance
            )
            PushRechargeOrderAttributionStore.notifyRechargePaymentSucceeded()
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            RechargeDesign.background
            Image(systemName: "sparkles")
                .font(.system(size: 200))
                .foregroundColor(RechargeDesign.purple.opacity(0.08))
                .blur(radius: 42)
        }
        .ignoresSafeArea()
    }

    private var rechargeListBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsRechargeVariantA {
                RechargeVariantAHeader()
                    .id(appLanguage.preference.storageValue)
                    .padding(.bottom, 14)
            }

            if showsRechargeVariantA {
                BBBTrackedText.text(
                    AppLanguageStore.localized("recharge.variant_a.packages_heading"),
                    size: 11,
                    weight: .heavy,
                    tracking: 1.8,
                    color: Color.white.opacity(0.55)
                )
                .padding(.bottom, 8)
            }

            packagesListSection

            VStack(spacing: 16) {
                Button {
                    guard let pkg = selectedPackage else { return }
                    Task {
                        await versionConfig.refresh()
                        let mode = await MainActor.run { versionConfig.rechargePresentationType }
                        if mode == 1 {
                            await completePurchaseDirectIAP(package: pkg)
                        } else {
                            await presentPaymentSelectionOrDirectAppleIfOnly(package: pkg)
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isPurchasing {
                            ProgressView()
                                .tint(RechargeDesign.ctaTitleDark)
                        }
                        BBBTrackedText.text(
                            AppLanguageStore.localized(
                                RechargeVariantALocalization.primaryCTAKey(
                                    isVariantA: showsRechargeVariantA,
                                    isPurchasing: isPurchasing
                                )
                            ),
                            size: 13,
                            weight: .heavy,
                            tracking: 2,
                            color: RechargeDesign.ctaTitleDark
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RechargeDesign.ctaGradient)
                    .clipShape(RoundedRectangle(cornerRadius: RechargeLayout.primaryButtonCorner, style: .continuous))
                    .shadow(color: RechargeDesign.purple.opacity(0.45), radius: 16, y: 6)
                    .shadow(color: RechargeDesign.pink.opacity(0.28), radius: 10, y: 4)
                }
                .disabled(selectedPackage == nil || isLoadingPackages || isPurchasing)
            }
            .padding(.top, 20)

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.78))
                BBBTrackedText.text(
                    AppLanguageStore.localized(
                        RechargeVariantALocalization.footerKey(isVariantA: showsRechargeVariantA)
                    ),
                    size: 9,
                    weight: .bold,
                    tracking: 2,
                    color: Color.white.opacity(0.72)
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var packagesListSection: some View {
        if isLoadingPackages && packages.isEmpty {
            ProgressView()
                .tint(AppTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
        } else if let err = packagesError, packages.isEmpty {
            VStack(spacing: 14) {
                Text(AppLanguageStore.localizedUserFacingAPIError(err))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.onSurface.opacity(0.75))
                    .multilineTextAlignment(.center)
                Button {
                    Task { await loadPackages() }
                } label: {
                    BBBTrackedText.text(AppLanguageStore.localized("common.retry"), size: 12, weight: .heavy, tracking: 1.2)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else if packages.isEmpty {
            Text(AppLanguageStore.localized("recharge.no_packages"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.onSurface.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        } else {
            LazyVStack(spacing: showsRechargeVariantA ? 12 : RechargeLayout.listRowSpacing) {
                ForEach(Array(packages.enumerated()), id: \.element.id) { index, pkg in
                    packageListCell(pkg, index: index)
                        .padding(.top, index == 0 ? RechargeLayout.scrollTopClearanceForBadgeOverflow : 0)
                }
            }
        }
    }

    private func loadPackages() async {
        await MainActor.run {
            isLoadingPackages = true
            packagesError = nil
        }
        let result = await RmPurchaseLedgerRepository.shared.getPackages()
        await MainActor.run {
            isLoadingPackages = false
            switch result {
            case .success(let list):
                domainPackages = list
                packages = list.map(RechargePackageModel.init(package:)).sorted { $0.packageId < $1.packageId }
                if selectedId == nil || packages.first(where: { $0.id == selectedId }) == nil {
                    selectedId = defaultSelectedPackageId()
                }
                applyPendingRechargeAppleProductSelection()
            case .failure(let err):
                domainPackages = []
                packages = []
                #if DEBUG
                if versionConfig.isPresentationVariantAUIEnabled {
                    domainPackages = RahmiAFaceLocalSimulation.domainPackages()
                    packages = domainPackages.map(RechargePackageModel.init(package:)).sorted { $0.packageId < $1.packageId }
                    if selectedId == nil || packages.first(where: { $0.id == selectedId }) == nil {
                        selectedId = defaultSelectedPackageId()
                    }
                    packagesError = nil
                } else {
                    packagesError = err.userMessage
                }
                #else
                packagesError = err.userMessage
                #endif
            }
        }
    }

    /// 远程推送 `recharge_incentive_new_user`：按 `apple_product_id` 匹配后台套餐并高亮选中。
    private func applyPendingRechargeAppleProductSelection() {
        guard let want = tabRouter.pendingRechargeAppleProductId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !want.isEmpty else { return }
        guard let domain = domainPackages.first(where: { ($0.resolvedAppleProductId ?? "") == want }) else { return }
        selectedId = "pkg-\(domain.id)"
        tabRouter.pendingRechargeAppleProductId = nil
    }

    private func packageBonusLine(_ pkg: RechargePackageModel, variantAStyle: Bool = false) -> Text {
        let suffix = AppLanguageStore.localized("recharge.package_bonus_suffix")
        let muted: Color = variantAStyle ? Color.white.opacity(0.58) : AppTheme.onSurfaceVariant
        return Text("\(pkg.base) + ")
            .foregroundColor(muted)
            + Text("\(pkg.bonus)")
            .foregroundColor(RechargeDesign.gold)
            + Text(" \(suffix)")
            .foregroundColor(muted)
    }

    /// 右侧「+% FREE」胶囊：按**赠送金币 / 基础金币**计算，与列表副行一致；无赠送时不展示
    private func rechargeListBonusPercentForBadge(_ pkg: RechargePackageModel) -> Int? {
        guard pkg.bonus > 0, pkg.base > 0 else { return nil }
        let rounded = (pkg.bonus * 100 + pkg.base / 2) / pkg.base
        return max(1, rounded)
    }

    private func packageListCell(_ pkg: RechargePackageModel, index: Int) -> some View {
        let variantA = showsRechargeVariantA
        let isSelected = selectedId == pkg.id
        let highlight = RechargeListRowHighlight.resolve(index: index, count: packages.count)
        let hasBonusLine = pkg.bonus > 0
        let showFeaturedChrome = isSelected
        let listCorner = variantA ? CGFloat(16) : RechargeLayout.listRowCorner
        let cardHeight = variantA ? CGFloat(82) : RechargeLayout.packageCardFixedHeight
        let hPad = variantA ? CGFloat(14) : RechargeLayout.packageRowHorizontalPadding
        let vPad = variantA ? CGFloat(11) : RechargeLayout.packageCardInnerVerticalPadding
        return Button {
            selectedId = pkg.id
            let domain = domainPackages.first(where: { $0.id == pkg.packageId })
            let amount = domain?.discountPrice ?? pkg.discountPriceCents
            Task {
                var extra: [String: Any] = ["package_id": String(pkg.packageId)]
                extra["amount"] = amount
                await RmClientTelemetryOutbox.shared.enqueue(
                    eventType: "recharge_package_select",
                    templateId: "",
                    taskId: nil,
                    ts: nil,
                    extra: extra
                )
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                rechargePackageLeadingCoinOrb(variantA: variantA, featured: showFeaturedChrome)

                VStack(alignment: .leading, spacing: hasBonusLine ? 3 : 0) {
                    Text(
                        AppLanguageStore.localizedFormat(
                            "recharge.package.coins_line",
                            Int64(hasBonusLine ? pkg.totalCoins : pkg.base)
                        )
                    )
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                    if hasBonusLine {
                        packageBonusLine(pkg, variantAStyle: variantA)
                            .font(.system(size: 11, weight: .semibold))
                            .textCase(.uppercase)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(pkg.price)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                    if let original = pkg.originalPrice {
                        Text(original)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(
                                variantA ? Color.white.opacity(0.45) : AppTheme.outlineVariant.opacity(0.78)
                            )
                            .strikethrough(true)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .frame(height: cardHeight)
            .background(rechargePackageRowBackground(variantA: variantA, corner: listCorner, featured: showFeaturedChrome))
            .overlay(rechargePackageRowStrokeOverlay(variantA: variantA, corner: listCorner, featured: showFeaturedChrome))
            .modifier(RechargePackageRowShadowModifier(variantA: variantA, featured: showFeaturedChrome))
            .overlay(alignment: .topLeading) {
                if highlight != .none {
                    rechargeListLeftBadge(highlight)
                        .padding(.leading, 10)
                        .offset(y: -8)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let pct = rechargeListBonusPercentForBadge(pkg) {
                    Text(String(format: AppLanguageStore.localized("recharge.badge.free_percent"), Int64(pct)))
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: variantA
                                            ? [AppTheme.accentCyan, RechargeDesign.pink.opacity(0.92)]
                                            : [RechargeDesign.pink, RechargeDesign.pink.opacity(0.88)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(
                            color: (variantA ? AppTheme.accentCyan : RechargeDesign.pink).opacity(0.45),
                            radius: 8,
                            y: 2
                        )
                        .padding(.trailing, 8)
                        .offset(y: -8)
                        .allowsHitTesting(false)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func rechargePackageLeadingCoinOrb(variantA: Bool, featured: Bool) -> some View {
        let d = RechargeLayout.coinIconDiameter
        if variantA {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(featured ? 0.12 : 0.055))
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: featured
                                ? [AppTheme.accentCyan.opacity(0.95), AppTheme.primary.opacity(0.78)]
                                : [Color.white.opacity(0.22), Color.white.opacity(0.07)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: featured ? 2 : 1
                    )
                AppCoinIcon(size: 22)
            }
            .frame(width: d, height: d)
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                RechargeDesign.purple.opacity(0.28),
                                RechargeDesign.pink.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: d, height: d)
                AppCoinIcon(size: 22)
            }
        }
    }

    @ViewBuilder
    private func rechargePackageRowBackground(variantA: Bool, corner: CGFloat, featured: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        if variantA {
            if featured {
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            AppTheme.accentCyan.opacity(0.07),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            } else {
                shape.fill(Color.white.opacity(0.06))
            }
        } else {
            shape.fill(featured ? RechargeDesign.cardFillElevated : RechargeDesign.cardFill)
        }
    }

    @ViewBuilder
    private func rechargePackageRowStrokeOverlay(variantA: Bool, corner: CGFloat, featured: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        if variantA {
            shape.stroke(
                LinearGradient(
                    colors: featured
                        ? [AppTheme.accentCyan, AppTheme.primary]
                        : [Color.white.opacity(0.14), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: featured ? 1.5 : 1
            )
        } else {
            shape.stroke(
                LinearGradient(
                    colors: featured
                        ? [RechargeDesign.purple, RechargeDesign.pink.opacity(0.92)]
                        : [Color.white.opacity(0.14), Color.white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: featured ? 2 : 1
            )
        }
    }

    @ViewBuilder
    private func rechargeListLeftBadge(_ highlight: RechargeListRowHighlight) -> some View {
        switch highlight {
        case .mostPopular:
            Text(AppLanguageStore.localized("recharge.badge.most_popular"))
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [RechargeDesign.purple.opacity(0.98), RechargeDesign.purple.opacity(0.82)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
                )
                .shadow(color: RechargeDesign.purple.opacity(0.55), radius: 8, y: 2)
        case .bestValue:
            Text(AppLanguageStore.localized("recharge.badge.best_value"))
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(Color.black.opacity(0.82))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [RechargeDesign.gold, RechargeDesign.gold.opacity(0.88)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: RechargeDesign.gold.opacity(0.45), radius: 8, y: 2)
        case .none:
            EmptyView()
        }
    }

    /// 支付方式弹窗模式：若接口仅配置 Apple 内购一条，则不弹 Sheet，直接拉起 StoreKit（与选 Apple 后点支付一致）
    private func presentPaymentSelectionOrDirectAppleIfOnly(package: RechargePackageModel) async {
        let mode = await MainActor.run { versionConfig.rechargePresentationType }
        if mode == 1 {
            await completePurchaseDirectIAP(package: package)
            return
        }
        await MainActor.run { isPurchasing = true }
        await RmCheckoutChannelRegistry.shared.loadPayChannelsOnce()
        let channels = await MainActor.run { RmCheckoutChannelRegistry.shared.payChannels }
        if channels.count == 1, let only = channels.first, only.isApplePay {
            await MainActor.run { isPurchasing = false }
            await completePurchase(package: package, payChannel: only)
            return
        }
        await MainActor.run {
            isPurchasing = false
            checkoutPackage = package
        }
    }

    /// 配置为「直接内购」时：先拉取 `/v3/pay_channels`，取 Apple 渠道；若无则使用 `PayChannel.fallbackApplePayForIAP`（与 `RmStoreKitPurchaseOrchestrator` pay_channel_id=1 一致）
    private func completePurchaseDirectIAP(package: RechargePackageModel) async {
        await RmCheckoutChannelRegistry.shared.loadPayChannelsOnce()
        let channels = await MainActor.run { RmCheckoutChannelRegistry.shared.payChannels }
        let apple: PayChannel = channels.first(where: { $0.isApplePay })
            ?? channels.first(where: { $0.id == 1 })
            ?? PayChannel.fallbackApplePayForIAP
        await completePurchase(package: package, payChannel: apple)
    }

    /// `payChannel.isApplePay` → `RmStoreKitPurchaseOrchestrator`；否则信用卡确认或重定向支付链接（与接口返回的 `pay_channel_id` 一致）
    private func completePurchase(package: RechargePackageModel, payChannel: PayChannel) async {
        guard auth.isAuthenticated else {
            await MainActor.run {
                paymentOutcome = .failed(message: AppLanguageStore.localized("recharge.error.login_first"))
            }
            return
        }
        guard let domain = domainPackages.first(where: { $0.id == package.packageId }) else {
            await MainActor.run {
                paymentOutcome = .failed(message: AppLanguageStore.localized("recharge.error.package_stale"))
            }
            return
        }

        let offerId = domain.offerIdForPushAttributedCreateOrderIfMatching()

        if !payChannel.isApplePay {
            await completeNonIAPPurchase(package: package, domain: domain, payChannel: payChannel, offerId: offerId)
            return
        }

        guard domain.resolvedAppleProductId != nil else {
            await MainActor.run {
                paymentOutcome = .failed(message: AppLanguageStore.localized("recharge.error.no_iap_product"))
            }
            return
        }
        guard RmStoreKitPurchaseOrchestrator.deviceAllowsInAppPurchases() else {
            await MainActor.run {
                paymentOutcome = .failed(message: RmStoreKitPurchaseOrchestrator.appStorePaymentsDisabledMessage)
            }
            return
        }
        await MainActor.run { isPurchasing = true }
        let iapChannelId = domain.iapPayChannelId ?? payChannel.id
        let result = await RmStoreKitPurchaseOrchestrator.shared.runIAPPurchaseFlow(package: domain, payChannelId: iapChannelId, offerId: offerId)
        await MainActor.run {
            isPurchasing = false
            checkoutPackage = nil
        }
        if result.success, result.gold > 0 {
            /// `RmStoreKitPurchaseOrchestrator` 已在 confirm 后用 `balance` 或 `refreshBalance` 更新钱包，省略二次拉取
            await finalizeRechargeSuccessUI(package: package, coinsAddedForRecord: result.gold, skipServerBalanceSync: true)
        } else if result.success, result.gold == 0 {
            await MainActor.run { paymentOutcome = nil }
        } else {
            await MainActor.run {
                paymentOutcome = .failed(message: iapFailureUserMessage())
            }
        }
    }

    private func iapFailureUserMessage() -> String {
        AppLanguageStore.localized("recharge.error.iap_failed_generic")
    }

    private func completeNonIAPPurchase(
        package: RechargePackageModel,
        domain: Package,
        payChannel: PayChannel,
        offerId: String?
    ) async {
        guard let uid = auth.userId else {
            await MainActor.run { paymentOutcome = .failed(message: AppLanguageStore.localized("recharge.error.login_first")) }
            return
        }

        let payChannelId = payChannel.id
        /// 与接口 type 一致；`id == 2` 且无 `redirect` 时按信用卡下单（兼容未填 type）
        let useCreditCardFlow = payChannel.isCreditCard
            || (payChannel.id == 2 && !payChannel.isRedirectPayment && !payChannel.isApplePay)
        let pageReturnURL = "\(APIBaseURL.effective)/payment/return"

        await MainActor.run { isPurchasing = true }

        if useCreditCardFlow {
            let orderResult = await RmPurchaseWireTransport.createRechargeOrder(
                userId: uid,
                packageId: domain.id,
                payChannelId: payChannelId,
                returnUrl: nil,
                pageUrl: nil,
                payload: nil,
                offerId: offerId
            )
            switch orderResult {
            case .failure(let err):
                await MainActor.run {
                    isPurchasing = false
                    paymentOutcome = .failed(message: AppLanguageStore.localizedUserFacingAPIError(err.userMessage))
                }
                return
            case .success(let resp):
                let orderId = resp.orderId
                guard let uid64 = Int64(uid) else {
                    await MainActor.run {
                        isPurchasing = false
                        paymentOutcome = .failed(message: AppLanguageStore.localized("recharge.error.user_id_invalid"))
                    }
                    return
                }
                await RmStoredCardCoordinator.shared.loadPaymentCards(userId: uid64)
                guard let card = RmStoredCardCoordinator.shared.defaultCard else {
                    await MainActor.run {
                        isPurchasing = false
                        paymentOutcome = .failed(message: AppLanguageStore.localized("recharge.error.bind_card_first"))
                    }
                    return
                }
                let payload = "{\"payment_card_id\":\(card.id)}"
                await RechargeBehaviorEvents.enqueueCreditCardPayStart(
                    packageId: domain.id,
                    payChannelId: payChannelId,
                    amountCents: domain.discountPrice
                )
                let confirmResult = await RmPurchaseLedgerRepository.shared.confirmRecharge(
                    orderId: orderId,
                    transactionId: "",
                    payChannelId: payChannelId,
                    payload: payload
                )
                await MainActor.run { isPurchasing = false }
                await handleNonIAPConfirmResult(
                    confirmResult,
                    package: package,
                    orderId: orderId,
                    payChannelId: payChannelId,
                    amountCents: domain.discountPrice
                )
                return
            }
        }

        let redirectResult = await RmPurchaseWireTransport.createRechargeOrder(
            userId: uid,
            packageId: domain.id,
            payChannelId: payChannelId,
            returnUrl: nil,
            pageUrl: pageReturnURL,
            payload: "{}",
            offerId: offerId
        )

        await MainActor.run { isPurchasing = false }

        switch redirectResult {
        case .failure(let err):
            await MainActor.run { paymentOutcome = .failed(message: AppLanguageStore.localizedUserFacingAPIError(err.userMessage)) }
        case .success(let resp):
            await RechargeBehaviorEvents.enqueueRedirectPayStart(
                orderId: resp.orderId,
                packageId: domain.id,
                payChannelId: payChannelId,
                amountCents: domain.discountPrice
            )
            if let urlStr = resp.paymentUrl,
               !urlStr.isEmpty,
               let url = URL(string: urlStr) {
                await MainActor.run {
                    checkoutPackage = nil
                    UIApplication.shared.open(url)
                    paymentOutcome = .openedPaymentPage(
                        message: AppLanguageStore.localized("recharge.error.open_browser_pay"),
                        orderId: resp.orderId,
                        package: package,
                        payChannelId: payChannelId
                    )
                }
            } else {
                await RechargeBehaviorEvents.enqueueRedirectPayFail(
                    orderId: resp.orderId,
                    packageId: domain.id,
                    payChannelId: payChannelId,
                    amountCents: domain.discountPrice,
                    reason: "no_payment_url"
                )
                await MainActor.run {
                    paymentOutcome = .failed(message: AppLanguageStore.localized("recharge.error.no_payment_url"))
                }
            }
        }
    }

    private func handleNonIAPConfirmResult(
        _ result: Result<ConfirmRechargeResponse, AppError>,
        package: RechargePackageModel,
        orderId: String,
        payChannelId: Int32,
        amountCents: Int64
    ) async {
        switch result {
        case .failure(let err):
            await RechargeBehaviorEvents.enqueueCreditCardPayFail(
                orderId: orderId,
                packageId: package.packageId,
                payChannelId: payChannelId,
                amountCents: amountCents,
                reason: err.userMessage
            )
            await MainActor.run { paymentOutcome = .failed(message: AppLanguageStore.localizedUserFacingAPIError(err.userMessage)) }
        case .success(let response):
            let dup = !response.success && RechargeOrderVerification.isDuplicateOrderSuccess(response.message)
            if response.success || dup {
                let coins = Int(response.goldAmount ?? "") ?? 0
                if coins > 0 {
                    let balanceRaw = response.balance?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    await RechargeBehaviorEvents.enqueueCreditCardPaySuccess(
                        orderId: orderId,
                        packageId: package.packageId,
                        payChannelId: payChannelId,
                        amountCents: amountCents
                    )
                    await MainActor.run {
                        checkoutPackage = nil
                        if !balanceRaw.isEmpty {
                            wallet.applyServerBalanceString(balanceRaw)
                        }
                    }
                    await finalizeRechargeSuccessUI(
                        package: package,
                        coinsAddedForRecord: coins,
                        skipServerBalanceSync: !balanceRaw.isEmpty
                    )
                } else {
                    await MainActor.run {
                        checkoutPackage = nil
                        paymentOutcome = nil
                    }
                }
            } else {
                await RechargeBehaviorEvents.enqueueCreditCardPayFail(
                    orderId: orderId,
                    packageId: package.packageId,
                    payChannelId: payChannelId,
                    amountCents: amountCents,
                    reason: response.message ?? "payment_failed"
                )
                await MainActor.run {
                    paymentOutcome = .failed(
                        message: AppLanguageStore.localizedUserFacingAPIError(
                            response.message ?? AppLanguageStore.localized("recharge.error.payment_incomplete")
                        )
                    )
                }
            }
        }
    }
}

// MARK: - 导航栏左上角

/// 充值 Tab 顶栏标题：A 面为 App Store 储值文案 + Apple 图标；B 面为信用卡图标 + RECHARGE
private struct RechargePageLeadingTitle: View {
    @EnvironmentObject private var versionConfig: VersionConfigStore
    @EnvironmentObject private var appLanguage: AppLanguageStore

    private var showsRechargeVariantA: Bool {
        versionConfig.isPresentationVariantAUIEnabled
    }

    private var titleKey: String {
        RechargeVariantALocalization.navigationTitleKey(isVariantA: showsRechargeVariantA)
    }

    private var title: String {
        RahmiTextStyle.navigationTitleLabel(AppLanguageStore.localized(titleKey))
    }

    var body: some View {
        let _ = appLanguage.preference
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.primary.opacity(0.28),
                                AppTheme.accentCyan.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .frame(width: 34, height: 34)

                Group {
                    if showsRechargeVariantA {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 16, weight: .semibold))
                    } else {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.accentCyan, AppTheme.primary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }

            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.88)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppLanguageStore.localized(titleKey))
    }
}

#Preview {
    RechargeView()
        .environmentObject(UserWalletStore())
        .environmentObject(AuthSessionStore())
        .environmentObject(VersionConfigStore())
        .environmentObject(AppLanguageStore())
        .environmentObject(AppTabRouter())
        .preferredColorScheme(.dark)
}
