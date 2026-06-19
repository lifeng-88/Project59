import SwiftUI

struct FocusModeGuideView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubLanguage) private var language

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LuminaSpacing.stackXL) {
                HubTopBar(
                    title: L10n.tr(.settingsAboutFocus, language: language),
                    showMenu: false,
                    onBack: { dismiss() }
                )

                pomodoroIntroCard
                stepsSection
                tipsSection
                startSection
            }
            .padding(.bottom, LuminaSpacing.stackXL)
        }
        .background(LuminaColor.surface)
        .navigationBarHidden(true)
    }

    private var startSection: some View {
        VStack(spacing: LuminaSpacing.stackMD) {
            Text(L10n.tr(.focusGuideReady, language: language))
                .font(.luminaLabelMD)
                .foregroundStyle(LuminaColor.onSurfaceVariant)

            Button {
                dismiss()
                store.startFocusSession()
            } label: {
                Text(L10n.tr(.settingsStartFocusNow, language: language))
                    .font(.luminaLabelMD.weight(.semibold))
                    .foregroundStyle(LuminaColor.onPrimary)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(LuminaColor.primary)
                    .clipShape(Capsule())
                    .luminaFABShadow()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LuminaSpacing.stackXL)
        .padding(.horizontal, LuminaSpacing.marginPage)
    }

    private var pomodoroIntroCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr(.focusGuideWhatIs, language: language))
                    .font(.luminaHeadlineMobile)
                    .foregroundStyle(LuminaColor.onPrimaryContainer)

                Text(L10n.tr(.focusGuideIntro, language: language))
                    .font(.luminaBodyMD)
                    .foregroundStyle(LuminaColor.onPrimaryContainer.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "timer")
                .font(.system(size: 100))
                .foregroundStyle(LuminaColor.onPrimary.opacity(0.1))
                .offset(x: 16, y: 16)
        }
        .background(LuminaColor.primaryContainer)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        .luminaSoftShadow()
        .padding(.horizontal, LuminaSpacing.marginPage)
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackMD) {
            Text(L10n.tr(.focusGuideHowTo, language: language))
                .font(.luminaHeadlineMobile)
                .foregroundStyle(LuminaColor.onSurface)
                .padding(.horizontal, LuminaSpacing.marginPage)

            VStack(spacing: LuminaSpacing.stackMD) {
                stepRow(
                    number: 1,
                    title: L10n.tr(.focusGuideStep1Title, language: language),
                    detail: L10n.tr(.focusGuideStep1Detail, language: language)
                )
                stepRow(
                    number: 2,
                    title: L10n.tr(.focusGuideStep2Title, language: language),
                    detail: L10n.tr(.focusGuideStep2Detail, language: language)
                )
                stepRow(
                    number: 3,
                    title: L10n.tr(.focusGuideStep3Title, language: language),
                    detail: L10n.tr(.focusGuideStep3Detail, language: language)
                )
                stepRow(
                    number: 4,
                    title: L10n.tr(.focusGuideStep4Title, language: language),
                    detail: L10n.tr(.focusGuideStep4Detail, language: language)
                )
            }
            .padding(.horizontal, LuminaSpacing.marginPage)
        }
    }

    private func stepRow(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: LuminaSpacing.stackMD) {
            Text("\(number)")
                .font(.luminaLabelSM)
                .foregroundStyle(LuminaColor.onPrimary)
                .frame(width: 28, height: 28)
                .background(LuminaColor.primary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.luminaBodyMD.weight(.semibold))
                    .foregroundStyle(LuminaColor.onSurface)
                Text(detail)
                    .font(.luminaBodyMD)
                    .foregroundStyle(LuminaColor.onSurfaceVariant)
            }
        }
        .padding(LuminaSpacing.insetMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LuminaColor.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        .luminaSoftShadow()
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackMD) {
            Text(L10n.tr(.focusGuideTips, language: language))
                .font(.luminaHeadlineMobile)
                .foregroundStyle(LuminaColor.onSurface)

            tipRow(icon: "iphone.slash", text: L10n.tr(.focusGuideTip1, language: language))
            tipRow(icon: "drop.fill", text: L10n.tr(.focusGuideTip2, language: language))
            tipRow(icon: "leaf.fill", text: L10n.tr(.focusGuideTip3, language: language))
        }
        .padding(LuminaSpacing.insetMD)
        .background(LuminaColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        .padding(.horizontal, LuminaSpacing.marginPage)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: LuminaSpacing.stackMD) {
            Image(systemName: icon)
                .foregroundStyle(LuminaColor.tertiary)
                .frame(width: 24)
            Text(text)
                .font(.luminaBodyMD)
                .foregroundStyle(LuminaColor.onSurfaceVariant)
        }
    }
}
