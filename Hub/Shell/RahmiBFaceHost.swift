import SwiftUI

/// 承载完整 Rahmi 业务（B 面）
struct RahmiBFaceHost: View {
    @EnvironmentObject private var faceController: AppFaceController
    @EnvironmentObject private var versionConfig: VersionConfigStore

    @StateObject private var wallet = UserWalletStore()
    @StateObject private var tabRouter = AppTabRouter()
    @StateObject private var auth = AuthSessionStore()
    @StateObject private var appLanguage = AppLanguageStore()
    @State private var secretTapCount = 0
    @State private var resetTask: Task<Void, Never>?

    private var surfaceSwitchBottomPadding: CGFloat {
        tabRouter.shouldHideTabBar ? 16 : MainTabBarMetrics.estimatedContentHeight + 16
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RahmiRootContentView()
                .environmentObject(wallet)
                .environmentObject(tabRouter)
                .environmentObject(auth)
                .environmentObject(versionConfig)
                .environmentObject(appLanguage)
                .environment(\.locale, appLanguage.effectiveLocale)
                .preferredColorScheme(.dark)

            exitControl
        }
        .onAppear {
            RahmiModule.configureIfNeeded()
            faceController.markRahmiBootstrapped()
        }
    }

    @ViewBuilder
    private var exitControl: some View {
        #if DEBUG
        if AppFaceController.showsManualFaceSwitchInUI,
           !tabRouter.shouldHideTabBar {
            HubFaceSwitchFAB(style: .rahmi)
                .padding(.leading, 16)
                .padding(.bottom, surfaceSwitchBottomPadding)
        }
        #else
        if faceController.allowsManualHubReturn, !tabRouter.shouldHideTabBar {
            Color.clear
                .frame(width: 56, height: 56)
                .contentShape(Rectangle())
                .onTapGesture { registerExitTap() }
                .padding(.leading, 8)
                .padding(.bottom, surfaceSwitchBottomPadding)
        }
        #endif
    }

    private func registerExitTap() {
        secretTapCount += 1
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            secretTapCount = 0
        }
        guard secretTapCount >= 7 else { return }
        secretTapCount = 0
        resetTask?.cancel()
        versionConfig.manualReturnToHubFace()
        faceController.switchToLumina()
    }
}
