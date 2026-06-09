import SwiftUI

/// 应用根：A 面 Lumina Hub / B 面 Rahmi（由 `/v1/app_config` 的 `type` 切换）
struct HubRootView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var faceController = AppFaceController()
    @StateObject private var versionConfig = VersionConfigStore()

    var body: some View {
        Group {
            if faceController.isShowingRahmi {
                RahmiBFaceHost()
            } else {
                ContentView()
                    .environmentObject(faceController)
            }
        }
        .environmentObject(faceController)
        .environmentObject(versionConfig)
        .animation(.easeInOut(duration: 0.28), value: faceController.activeFace)
        .task {
            await versionConfig.bootstrapOnColdStart()
            faceController.applyPresentationType(versionConfig.rechargePresentationType)
        }
        .onChange(of: versionConfig.rechargePresentationType) { newType in
            faceController.applyPresentationType(newType)
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task {
                await versionConfig.refreshIfNeeded()
                faceController.applyPresentationType(versionConfig.rechargePresentationType)
            }
        }
    }
}
