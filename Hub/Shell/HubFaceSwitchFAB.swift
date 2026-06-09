import SwiftUI

/// 首页悬浮按钮：在已解锁时于 A/B 面之间切换
struct HubFaceSwitchFAB: View {
    @EnvironmentObject private var faceController: AppFaceController

    var style: Style = .lumina

    enum Style {
        case lumina
        case rahmi
    }

    var body: some View {
        if AppFaceController.showsManualFaceSwitchInUI, AppFaceController.isBFaceUnlocked {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                faceController.toggleFace()
            } label: {
                labelContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityText)
        }
    }

    @ViewBuilder
    private var labelContent: some View {
        switch style {
        case .lumina:
            luminaLabel
        case .rahmi:
            rahmiLabel
        }
    }

    private var luminaLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: targetIcon)
                .font(.system(size: 18, weight: .semibold))
            Text(targetShortTitle)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(LuminaColor.onSecondaryContainer)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(LuminaColor.secondaryContainer)
        .clipShape(Capsule())
        .luminaFABShadow()
    }

    private var rahmiLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: targetIcon)
                .font(.system(size: 18, weight: .semibold))
            Text(targetShortTitle)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
    }

    private var switchingToRahmi: Bool { !faceController.isShowingRahmi }

    private var targetIcon: String {
        switchingToRahmi ? "sparkles" : "calendar.circle.fill"
    }

    private var targetShortTitle: String {
        switchingToRahmi ? "Rahmi" : "Hub"
    }

    private var accessibilityText: String {
        switchingToRahmi ? "切换到 Rahmi" : "切换到 Hub"
    }
}
