import SwiftUI

/// 承载完整 Rahmi 业务（B 面）
struct RahmiBFaceHost: View {
    @EnvironmentObject private var faceController: AppFaceController
    @EnvironmentObject private var versionConfig: VersionConfigStore

    @StateObject private var wallet = UserWalletStore()
    @StateObject private var tabRouter = AppTabRouter()
    @StateObject private var auth = AuthSessionStore()
    @StateObject private var appLanguage = AppLanguageStore()

    var body: some View {
        RahmiRootContentView()
            .environmentObject(wallet)
            .environmentObject(tabRouter)
            .environmentObject(auth)
            .environmentObject(versionConfig)
            .environmentObject(appLanguage)
            .environment(\.locale, appLanguage.effectiveLocale)
            .preferredColorScheme(.dark)
            .overlay(alignment: .bottomLeading) {
                if AppFaceController.showsManualFaceSwitchInUI,
                   !tabRouter.shouldHideTabBar {
                    HubFaceSwitchFAB(style: .rahmi)
                        .padding(.leading, 16)
                        .padding(.bottom, MainTabBarMetrics.estimatedContentHeight + 16)
                }
            }
            .onAppear {
                RahmiModule.configureIfNeeded()
                faceController.markRahmiBootstrapped()
            }
    }
}
