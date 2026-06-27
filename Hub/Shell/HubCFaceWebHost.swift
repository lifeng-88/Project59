import SwiftUI

/// C 面：全屏 H5 WebView（Morph `BSideView` / `MorphH5WebView` 对齐），由 `app_config.type == 2` 驱动。
struct HubCFaceWebHost: View {
    @EnvironmentObject private var faceController: AppFaceController
    @StateObject private var webViewModel: HubH5WebViewModel

    init() {
        _webViewModel = StateObject(wrappedValue: HubH5WebViewModel(pageURL: ResBaseURL.cFaceURL))
    }

    var body: some View {
        ZStack {
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
        }
        .overlay(alignment: .bottomLeading) {
            if AppFaceController.showsManualFaceSwitchInUI {
                HubFaceSwitchFAB(style: .web)
                    .padding(.leading, LuminaSpacing.marginPage)
                    .padding(.bottom, 24)
            }
        }
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
}
