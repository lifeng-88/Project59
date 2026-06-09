import SwiftUI
import UIKit

// Lumina Focus — 浅色 / 深色自适应色板（基于 DESIGN.md Material 语义色）
enum LuminaColor {
  // MARK: - Surface
  static let surface = Color.lumina(light: 0xF8F9FA, dark: 0x121416)
  static let surfaceContainerLowest = Color.lumina(light: 0xFFFFFF, dark: 0x1C1F23)
  static let surfaceContainerLow = Color.lumina(light: 0xF3F4F5, dark: 0x22262B)
  static let surfaceContainer = Color.lumina(light: 0xEDEEEF, dark: 0x272B30)
  static let surfaceContainerHigh = Color.lumina(light: 0xE7E8E9, dark: 0x2C3137)
  static let surfaceVariant = Color.lumina(light: 0xE1E3E4, dark: 0x32383E)

  // MARK: - On surface
  static let onSurface = Color.lumina(light: 0x191C1D, dark: 0xE2E3E8)
  static let onSurfaceVariant = Color.lumina(light: 0x414751, dark: 0xA1A6B0)
  static let onBackground = Color.lumina(light: 0x191C1D, dark: 0xE2E3E8)

  // MARK: - Primary（深色下使用更亮的宁静蓝，保证对比度）
  static let primary = Color.lumina(light: 0x005DA7, dark: 0xA4C9FF)
  static let onPrimary = Color.lumina(light: 0xFFFFFF, dark: 0x001C39)
  static let primaryContainer = Color.lumina(light: 0x2976C7, dark: 0x1A4975)
  static let onPrimaryContainer = Color.lumina(light: 0xFDFCFF, dark: 0xD4E3FF)
  static let primaryFixed = Color.lumina(light: 0xD4E3FF, dark: 0x1A3A5C)
  static let primaryFixedDim = Color.lumina(light: 0xA4C9FF, dark: 0x7EB4E8)

  // MARK: - Secondary & outline
  static let secondary = Color.lumina(light: 0x5B5F63, dark: 0xB8BCC2)
  static let secondaryContainer = Color.lumina(light: 0xDDE0E5, dark: 0x3A3F45)
  static let onSecondaryContainer = Color.lumina(light: 0x5F6368, dark: 0xDDE0E5)
  static let outline = Color.lumina(light: 0x717783, dark: 0x8B919C)
  static let outlineVariant = Color.lumina(light: 0xC1C7D3, dark: 0x434851)

  // MARK: - Tertiary
  static let tertiary = Color.lumina(light: 0x7F5300, dark: 0xFFB953)
  static let tertiaryContainer = Color.lumina(light: 0xA06900, dark: 0x6B4800)
  static let tertiaryFixedDim = Color.lumina(light: 0xFFB953, dark: 0xFFCA80)

  // MARK: - Error
  static let error = Color.lumina(light: 0xBA1A1A, dark: 0xFFB4AB)
  static let onError = Color.lumina(light: 0xFFFFFF, dark: 0x690005)
  static let errorContainer = Color.lumina(light: 0xFFDAD6, dark: 0x93000A)
  static let onErrorContainer = Color.lumina(light: 0x93000A, dark: 0xFFDAD6)

  /// 遮罩基色（使用时配合 opacity）
  static let scrim = Color.lumina(light: 0x191C1D, dark: 0x000000)
}

enum LuminaSpacing {
  static let marginPage: CGFloat = 24
  static let stackXL: CGFloat = 40
  static let stackMD: CGFloat = 16
  static let stackSM: CGFloat = 8
  static let insetMD: CGFloat = 16
  static let gutter: CGFloat = 12
}

enum LuminaRadius {
  static let sm: CGFloat = 4
  static let md: CGFloat = 12
  static let lg: CGFloat = 16
  static let sheetTop: CGFloat = 32
}

// MARK: - Color helpers

extension Color {
  init(hex: UInt32, alpha: Double = 1) {
    let r = Double((hex >> 16) & 0xFF) / 255
    let g = Double((hex >> 8) & 0xFF) / 255
    let b = Double(hex & 0xFF) / 255
    self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
  }

  /// 随系统 / `preferredColorScheme` 自动切换的语义色
  static func lumina(light: UInt32, dark: UInt32) -> Color {
    Color(uiColor: UIColor { traits in
      let hex = traits.userInterfaceStyle == .dark ? dark : light
      return UIColor(hex: hex)
    })
  }
}

extension UIColor {
  convenience init(hex: UInt32, alpha: CGFloat = 1) {
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat(hex & 0xFF) / 255
    self.init(red: r, green: g, blue: b, alpha: alpha)
  }
}

// MARK: - View modifiers

extension View {
  func luminaScreenBackground() -> some View {
    background(LuminaColor.surface)
  }

  func luminaSoftShadow() -> some View {
    modifier(LuminaShadowModifier(intensity: .soft))
  }

  func luminaFABShadow() -> some View {
    modifier(LuminaShadowModifier(intensity: .fab))
  }
}

private enum LuminaShadowIntensity {
  case soft, fab
}

private struct LuminaShadowModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  let intensity: LuminaShadowIntensity

  func body(content: Content) -> some View {
    switch intensity {
    case .soft:
      content.shadow(
        color: shadowColor(opacity: colorScheme == .dark ? 0.45 : 0.04),
        radius: colorScheme == .dark ? 8 : 10,
        x: 0,
        y: colorScheme == .dark ? 2 : 4
      )
    case .fab:
      content.shadow(
        color: shadowColor(opacity: colorScheme == .dark ? 0.55 : 0.08),
        radius: colorScheme == .dark ? 12 : 15,
        x: 0,
        y: colorScheme == .dark ? 4 : 8
      )
      .shadow(
        color: colorScheme == .dark ? LuminaColor.primary.opacity(0.15) : .clear,
        radius: 12,
        x: 0,
        y: 4
      )
    }
  }

  private func shadowColor(opacity: Double) -> Color {
    colorScheme == .dark ? Color.black.opacity(opacity) : Color.black.opacity(opacity)
  }
}

/// 根视图主题：背景、强调色、导航栏/列表外观
struct LuminaRootThemeModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .tint(LuminaColor.primary)
      .background(LuminaColor.surface)
      .onAppear {
        applyUIKitAppearance(for: colorScheme)
      }
      .onChange(of: colorScheme) { _, newScheme in
        applyUIKitAppearance(for: newScheme)
      }
  }

  private func applyUIKitAppearance(for scheme: ColorScheme) {
    let nav = UINavigationBarAppearance()
    nav.configureWithOpaqueBackground()
    nav.backgroundColor = UIColor(LuminaColor.surface)
    nav.titleTextAttributes = [.foregroundColor: UIColor(LuminaColor.onSurface)]
    nav.largeTitleTextAttributes = [.foregroundColor: UIColor(LuminaColor.onSurface)]

    UINavigationBar.appearance().standardAppearance = nav
    UINavigationBar.appearance().scrollEdgeAppearance = nav
    UINavigationBar.appearance().compactAppearance = nav
    UINavigationBar.appearance().tintColor = UIColor(LuminaColor.primary)

    UITableView.appearance().backgroundColor = .clear
    UITableViewCell.appearance().backgroundColor = UIColor(LuminaColor.surfaceContainerLowest)

    let isDark = scheme == .dark
    UITextField.appearance().keyboardAppearance = isDark ? .dark : .light
  }
}

extension View {
  func luminaRootTheme() -> some View {
    modifier(LuminaRootThemeModifier())
  }
}
