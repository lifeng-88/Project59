import SwiftUI

/// 应用根：A 面 Lumina Hub / B 面 Rahmi（type=3）/ C 面 WebView（type=2）
struct HubRootView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var faceController = AppFaceController()
    @StateObject private var versionConfig = VersionConfigStore()

    var body: some View {
        Group {
            if versionConfig.isBootstrapComplete {
                rootContent
            } else {
                HubLaunchLoadingView()
            }
        }
        .environmentObject(faceController)
        .environmentObject(versionConfig)
        .animation(.easeInOut(duration: 0.28), value: faceController.activeFace)
        .animation(.easeInOut(duration: 0.25), value: versionConfig.isBootstrapComplete)
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

    @ViewBuilder
    private var rootContent: some View {
        Group {
            if faceController.isShowingWeb {
                HubCFaceWebHost()
            } else if faceController.isShowingRahmi {
                RahmiBFaceHost()
            } else {
                ContentView()
                    .environmentObject(faceController)
            }
        }
    }
}

private struct HubLaunchLoadingView: View {
    var body: some View {
        ZStack {
            LuminaColor.surface.ignoresSafeArea()
            VStack(spacing: LuminaSpacing.stackXL) {
                Text("Lumina Focus")
                    .font(.luminaDisplay)
                    .foregroundStyle(LuminaColor.primary)
                ProgressView()
                    .tint(LuminaColor.primary)
            }
        }
    }
}
