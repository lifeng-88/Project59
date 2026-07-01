import SwiftUI

/// C 面：全屏 H5 WebView（对齐 Ebruk `SurfaceCContainerView`），由 `app_config.type == 2` 驱动。
struct HubCFaceWebHost: View {
    @EnvironmentObject private var faceController: AppFaceController
    @EnvironmentObject private var versionConfig: VersionConfigStore

    var body: some View {
        if let pageURL = versionConfig.surfaceWebURL ?? HubCFaceConfig.resolveURL(remoteURLString: nil) {
            HubCFaceWebContent(pageURL: pageURL)
                .id(pageURL.absoluteString)
                .environmentObject(faceController)
                .environmentObject(versionConfig)
        } else {
            missingURLState
        }
    }

    private var missingURLState: some View {
        VStack(spacing: LuminaSpacing.stackMD) {
            Image(systemName: "globe")
                .font(.system(size: 44))
                .foregroundStyle(LuminaColor.outline)
            Text("C 面 H5 地址未配置")
                .font(.luminaBodyLG)
                .foregroundStyle(LuminaColor.onSurface)
            Button("返回 Hub") {
                returnToHubFace()
            }
            .font(.luminaLabelMD.weight(.semibold))
            .foregroundStyle(LuminaColor.onPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(LuminaColor.primary)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LuminaColor.surface.ignoresSafeArea())
    }

    private func returnToHubFace() {
        versionConfig.manualReturnToHubFace()
        faceController.switchToLumina()
    }
}

private struct HubCFaceWebContent: View {
    @EnvironmentObject private var faceController: AppFaceController
    @EnvironmentObject private var versionConfig: VersionConfigStore

    let pageURL: URL
    @StateObject private var webViewModel: HubH5WebViewModel
    @State private var secretTapCount = 0
    @State private var resetTask: Task<Void, Never>?

    init(pageURL: URL) {
        self.pageURL = pageURL
        _webViewModel = StateObject(wrappedValue: HubH5WebViewModel(pageURL: pageURL))
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LuminaColor.surface.ignoresSafeArea()

            HubH5WebView(viewModel: webViewModel)
                .opacity(webViewModel.isReady ? 1 : 0)
                .ignoresSafeArea(edges: .bottom)

            if !webViewModel.isReady, webViewModel.errorMessage == nil {
                ProgressView()
                    .tint(LuminaColor.primary)
                    .scaleEffect(1.2)
            }

            if let errorMessage = webViewModel.errorMessage {
                errorOverlay(message: errorMessage)
            }

            exitControl
        }
    }

    @ViewBuilder
    private var exitControl: some View {
        #if DEBUG
        if AppFaceController.showsManualFaceSwitchInUI {
            HubFaceSwitchFAB(style: .web)
                .padding(.leading, LuminaSpacing.marginPage)
                .padding(.bottom, 24)
        }
        #else
        Color.clear
            .frame(width: 56, height: 56)
            .contentShape(Rectangle())
            .onTapGesture { registerExitTap() }
            .padding(.leading, 8)
            .padding(.bottom, 16)
        #endif
    }

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: LuminaSpacing.stackMD) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(LuminaColor.outline)

            Text(message)
                .font(.luminaBodyMD)
                .foregroundStyle(LuminaColor.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, LuminaSpacing.marginPage)

            Button {
                webViewModel.reload()
            } label: {
                Text("Retry")
                    .font(.luminaLabelMD.weight(.semibold))
                    .foregroundStyle(LuminaColor.onPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(LuminaColor.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LuminaColor.surface.opacity(0.92))
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
