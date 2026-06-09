//
//  IOS15Compat.swift
//  Rahmi
//
//  iOS 15 最低版本下的 SwiftUI API 兼容（16+ API 做可用性分支）
//

import SwiftUI
import UIKit

// MARK: - 导航栏返回与全局着色

/// 统一导航栏返回箭头 / BarButton 主色，以及可复用的自定义返回按钮（易点、轻触反馈）。
enum BBBNavigationChrome {
    /// 在 App 启动时调用一次：系统返回箭头与导航栏按钮使用品牌主色。
    static func applyGlobalTint() {
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.primary)
    }
}

/// 自定义返回（隐藏系统返回时）：仅箭头或「箭头 + 返回」、`contentShape` 保证整块可点，轻触反馈。
struct BBBNavigationBackButton: View {
    /// `true` 时显示本地化「返回」文案；`false` 仅箭头（更紧凑，依赖无障碍读屏标签）。
    var showsLocalizedTitle: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 17, weight: .semibold))
                if showsLocalizedTitle {
                    Text(AppLanguageStore.localized("common.back"))
                        .font(.system(size: 17, weight: .medium))
                }
            }
            .foregroundStyle(AppTheme.primary)
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppLanguageStore.localized("common.back"))
    }
}

/// 用 `BBBNavigationBackButton` + `common.back` 替换系统返回，使文案与 `AppLanguageStore` 一致（而非仅跟随系统区域设置）。
private struct BBBLocalizedNavigationBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    var showsLocalizedTitle: Bool

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BBBNavigationBackButton(showsLocalizedTitle: showsLocalizedTitle) {
                        dismiss()
                    }
                }
            }
    }
}

extension View {
    /// 自定义返回按钮，文案与读屏标签使用 `common.back` 的 String Catalog 翻译。
    func rahmiLocalizedNavigationBackButton(showsLocalizedTitle: Bool = false) -> some View {
        modifier(BBBLocalizedNavigationBackButtonModifier(showsLocalizedTitle: showsLocalizedTitle))
    }
}

// MARK: - 文案展示（字距 / 大写）

/// B 面标签排版：避免中文前导空隙、避免对 CJK 强行全大写
enum RahmiTextStyle {
    /// 西文装饰标签用大写；含中文/日文/韩文则保持原文
    static func latinDisplayLabel(_ text: String) -> String {
        containsCJK(in: text) ? text : text.uppercased()
    }

    /// 导航栏标题：CJK 保持原文；西文用语义化首字母大写（非全大写）
    static func navigationTitleLabel(_ text: String) -> String {
        containsCJK(in: text) ? text : text.capitalized
    }

    /// 中文等不拉大 tracking，减轻「字前多空一块」的观感
    static func effectiveTracking(for string: String, design: CGFloat) -> CGFloat {
        guard design > 0 else { return 0 }
        if containsCJK(in: string) { return min(design, 0.15) }
        return design
    }

    static func containsCJK(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x4E00...0x9FFF, 0x3400...0x4DBF,
                 0x3040...0x30FF, 0x31F0...0x31FF, 0xAC00...0xD7AF,
                 0x3000...0x303F, 0xFF00...0xFFEF:
                return true
            default:
                return false
            }
        }
    }

    /// 字距加在字符之间，不对首字施加 kern，避免 SwiftUI 里出现左侧「假前缀」空隙
    static func applyInterCharacterKern(_ tracking: CGFloat, to attributed: NSMutableAttributedString) {
        guard tracking != 0 else { return }
        let length = attributed.length
        guard length > 1 else { return }
        for index in 0..<(length - 1) {
            attributed.addAttribute(.kern, value: tracking, range: NSRange(location: index, length: 1))
        }
    }
}

/// iOS 15：`Text.tracking` / `kerning` 仅 iOS 16+；统一走 `RahmiTextStyle` 的字距策略
enum BBBTrackedText {
    static func text(
        _ string: String,
        size: CGFloat,
        weight: UIFont.Weight = .regular,
        tracking: CGFloat,
        color: Color? = nil,
        italic: Bool = false,
        serif: Bool = false
    ) -> Text {
        let kern = RahmiTextStyle.effectiveTracking(for: string, design: tracking)

        if #available(iOS 16.0, *) {
            var line = Text(string)
                .font(Font(uiFont(size: size, weight: weight, italic: italic, serif: serif)))
            if kern != 0 {
                line = line.tracking(kern)
            }
            if let color {
                line = line.foregroundStyle(color)
            }
            return line
        }

        let attributed = NSMutableAttributedString(string: string)
        let range = NSRange(location: 0, length: attributed.length)
        attributed.addAttribute(.font, value: uiFont(size: size, weight: weight, italic: italic, serif: serif), range: range)
        if let color {
            attributed.addAttribute(.foregroundColor, value: UIColor(color), range: range)
        }
        RahmiTextStyle.applyInterCharacterKern(kern, to: attributed)
        return Text(AttributedString(attributed))
    }

    private static func uiFont(size: CGFloat, weight: UIFont.Weight, italic: Bool, serif: Bool) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let designed: UIFont
        if serif, let descriptor = base.fontDescriptor.withDesign(.serif) {
            designed = UIFont(descriptor: descriptor, size: size)
        } else {
            designed = base
        }
        guard italic else { return designed }
        let traits = designed.fontDescriptor.symbolicTraits.union(.traitItalic)
        if let descriptor = designed.fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return designed
    }
}

/// iOS 16+ `listRowSeparatorTint`；低版本不处理
struct ListRowSeparatorTintIfAvailable: ViewModifier {
    let tint: Color
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.listRowSeparatorTint(tint)
        } else {
            content
        }
    }
}

extension View {
    @ViewBuilder
    func rahmiNavigationBarBackground(_ color: Color) -> some View {
        if #available(iOS 16.0, *) {
            self.toolbarBackground(color, for: .navigationBar)
        } else {
            self
        }
    }

    @ViewBuilder
    func rahmiToolbarHiddenNavigationBar() -> some View {
        if #available(iOS 16.0, *) {
            self.toolbar(.hidden, for: .navigationBar)
        } else {
            self.navigationBarHidden(true)
        }
    }

    @ViewBuilder
    func rahmiToolbarVisibleNavigationBar() -> some View {
        if #available(iOS 16.0, *) {
            self.toolbar(.visible, for: .navigationBar)
        } else {
            self.navigationBarHidden(false)
        }
    }

    @ViewBuilder
    func rahmiScrollIndicatorsHidden() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollIndicators(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func rahmiScrollBounceBasedOnSize() -> some View {
        if #available(iOS 16.4, *) {
            self.scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }

    /// 关闭 ScrollView 子视图超出滚动边界的裁切（如负 offset 角标）；iOS 17+
    @ViewBuilder
    func rahmiScrollClipDisabledIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            self.scrollClipDisabled(true)
        } else {
            self
        }
    }

    @ViewBuilder
    func rahmiListScrollContentHidden() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }

    /// 大卡片式 sheet；iOS 15 无 `presentationDetents`，仅全屏呈现
    @ViewBuilder
    func rahmiSheetLargeIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}

// MARK: - 底部 TabBar 形状

/// 仅顶部两角圆角；贴屏幕底缘时底边为直线，避免四角 `RoundedRectangle` 与 Home Indicator / 屏底裁切冲突。
struct BBBTopRoundedRectangle: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        let bezier = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: r, height: r)
        )
        return Path(bezier.cgPath)
    }
}
