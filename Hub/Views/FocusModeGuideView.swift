import SwiftUI

struct FocusModeGuideView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LuminaSpacing.stackXL) {
                HubTopBar(title: "关于专注模式", showMenu: false, onBack: { dismiss() })

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
            Text("准备好开始您的第一个番茄钟了吗？")
                .font(.luminaLabelMD)
                .foregroundStyle(LuminaColor.onSurfaceVariant)

            Button {
                dismiss()
                store.startFocusSession()
            } label: {
                Text("立即开始专注")
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
                Text("什么是番茄工作法？")
                    .font(.luminaHeadlineMobile)
                    .foregroundStyle(LuminaColor.onPrimaryContainer)

                Text("番茄工作法（Pomodoro Technique）是一种简单易行的延时管理方法。通过将工作时间切分为 25 分钟的「番茄钟」和 5 分钟的休息，帮助您保持高强度的专注，同时避免过度疲劳。")
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
            Text("如何使用")
                .font(.luminaHeadlineMobile)
                .foregroundStyle(LuminaColor.onSurface)
                .padding(.horizontal, LuminaSpacing.marginPage)

            VStack(spacing: LuminaSpacing.stackMD) {
                stepRow(number: 1, title: "选择任务", detail: "从今日列表中挑选一项需要专注完成的任务。")
                stepRow(number: 2, title: "启动番茄钟", detail: "设置 25 分钟计时，期间避免一切干扰。")
                stepRow(number: 3, title: "短休息", detail: "计时结束后休息 5 分钟，起身活动、补充水分。")
                stepRow(number: 4, title: "循环重复", detail: "完成 4 个番茄钟后，进行一次 15–30 分钟的长休息。")
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
            Text("专注小贴士")
                .font(.luminaHeadlineMobile)
                .foregroundStyle(LuminaColor.onSurface)

            tipRow(icon: "iphone.slash", text: "开启勿扰模式，将手机翻面放置。")
            tipRow(icon: "drop.fill", text: "番茄钟开始前准备好饮用水。")
            tipRow(icon: "leaf.fill", text: "休息时远离屏幕，做简单的伸展运动。")
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
