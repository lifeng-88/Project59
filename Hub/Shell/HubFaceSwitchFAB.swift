import SwiftUI

/// 首页悬浮按钮：DEBUG 下在 Hub / Rahmi / Web 三面之间循环切换
struct HubFaceSwitchFAB: View {
    @EnvironmentObject private var faceController: AppFaceController
    @EnvironmentObject private var versionConfig: VersionConfigStore
    @Environment(\.hubLanguage) private var language

    var style: Style = .lumina

    enum Style {
        case lumina
        case rahmi
        case web
    }

    var body: some View {
        if shouldShow {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                handleTap()
            } label: {
                labelContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityText)
        }
    }

    private var shouldShow: Bool {
        switch style {
        case .lumina:
            return faceController.showsBFaceEntryOnHub
        case .rahmi, .web:
            return AppFaceController.showsManualFaceSwitchInUI
        }
    }

    private func handleTap() {
        switch style {
        case .lumina:
            enterBFace()
        case .rahmi, .web:
            #if DEBUG
            cycleDebugFace()
            #endif
        }
    }

    private func enterBFace() {
        #if DEBUG
        if AppFaceController.showsManualFaceSwitchInUI {
            versionConfig.debugSetPresentationType(3)
            faceController.applyPresentationType(3)
            return
        }
        #endif
        faceController.switchToRahmi()
    }

    #if DEBUG
    private func cycleDebugFace() {
        let nextType: Int
        switch faceController.activeFace {
        case .lumina: nextType = 3
        case .rahmi: nextType = 2
        case .web: nextType = 1
        }
        versionConfig.debugSetPresentationType(nextType)
        faceController.applyPresentationType(nextType)
    }
    #endif

    @ViewBuilder
    private var labelContent: some View {
        switch style {
        case .lumina:
            luminaLabel
        case .rahmi:
            rahmiLabel
        case .web:
            webLabel
        }
    }

    private var luminaLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: targetIcon)
                .font(.system(size: 18, weight: .semibold))
            Text(targetShortTitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(LuminaColor.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(LuminaColor.secondaryContainer)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(LuminaColor.primary.opacity(0.2), lineWidth: 1)
        )
        .luminaSoftShadow()
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

    private var webLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: targetIcon)
                .font(.system(size: 18, weight: .semibold))
            Text(targetShortTitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(LuminaColor.onPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(LuminaColor.primary.opacity(0.88))
        .clipShape(Capsule())
        .shadow(color: LuminaColor.primary.opacity(0.25), radius: 8, y: 4)
    }

    private var targetIcon: String {
        switch nextFace {
        case .rahmi: return "sparkles"
        case .web: return "globe"
        case .lumina: return "calendar.circle.fill"
        }
    }

    private var targetShortTitle: String {
        switch nextFace {
        case .rahmi: return "Rahmi"
        case .web: return "Web"
        case .lumina: return "Hub"
        }
    }

    private var accessibilityText: String {
        switch nextFace {
        case .rahmi: return L10n.tr(.faceSwitchToRahmi, language: language)
        case .web: return L10n.tr(.faceSwitchToWeb, language: language)
        case .lumina: return L10n.tr(.faceSwitchToHub, language: language)
        }
    }

    private var nextFace: AppFaceController.Face {
        switch faceController.activeFace {
        case .lumina: return .rahmi
        case .rahmi: return .web
        case .web: return .lumina
        }
    }
}
