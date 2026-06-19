import SwiftUI
import UIKit

// Lumina Focus — 偏女性化：暖粉、玫瑰、薰衣草语义色（浅色 / 深色自适应）
enum LuminaColor {
  // MARK: - Surface（暖象牙 / 深梅紫底）
  static let surface = Color.lumina(light: 0xFBF7F9, dark: 0x161218)
  static let surfaceContainerLowest = Color.lumina(light: 0xFFFFFF, dark: 0x1F1A22)
  static let surfaceContainerLow = Color.lumina(light: 0xF7F0F4, dark: 0x262029)
  static let surfaceContainer = Color.lumina(light: 0xF0E6EC, dark: 0x2C252F)
  static let surfaceContainerHigh = Color.lumina(light: 0xE8DCE4, dark: 0x332B36)
  static let surfaceVariant = Color.lumina(light: 0xE2D4DC, dark: 0x3A313D)

  // MARK: - On surface（暖灰紫文字）
  static let onSurface = Color.lumina(light: 0x3D2F38, dark: 0xF5EEF2)
  static let onSurfaceVariant = Color.lumina(light: 0x7A6570, dark: 0xB8A8B0)
  static let onBackground = Color.lumina(light: 0x3D2F38, dark: 0xF5EEF2)

  // MARK: - Primary（玫瑰主色）
  static let primary = Color.lumina(light: 0xC45C8A, dark: 0xF0A8C8)
  static let onPrimary = Color.lumina(light: 0xFFFFFF, dark: 0x3D1028)
  static let primaryContainer = Color.lumina(light: 0xE8A4C4, dark: 0x5C2848)
  static let onPrimaryContainer = Color.lumina(light: 0x4A1028, dark: 0xFFE8F2)
  static let primaryFixed = Color.lumina(light: 0xF5D5E8, dark: 0x4A2038)
  static let primaryFixedDim = Color.lumina(light: 0xE8B4CC, dark: 0xC87898)

  // MARK: - Secondary & outline（藕荷 / 灰紫）
  static let secondary = Color.lumina(light: 0x8B6B7A, dark: 0xC8B0BC)
  static let secondaryContainer = Color.lumina(light: 0xF5E8EE, dark: 0x3A3038)
  static let onSecondaryContainer = Color.lumina(light: 0x6B5058, dark: 0xF0E0E8)
  static let outline = Color.lumina(light: 0xA8949E, dark: 0x8A7882)
  static let outlineVariant = Color.lumina(light: 0xD4C4CC, dark: 0x4A4048)

  // MARK: - Tertiary（薰衣草点缀）
  static let tertiary = Color.lumina(light: 0x8B6BA8, dark: 0xC8A8E8)
  static let tertiaryContainer = Color.lumina(light: 0xB898D4, dark: 0x5C4080)
  static let tertiaryFixedDim = Color.lumina(light: 0xD4B8E8, dark: 0xA888C8)

  // MARK: - Error
  static let error = Color.lumina(light: 0xBA1A1A, dark: 0xFFB4AB)
  static let onError = Color.lumina(light: 0xFFFFFF, dark: 0x690005)
  static let errorContainer = Color.lumina(light: 0xFFDAD6, dark: 0x93000A)
  static let onErrorContainer = Color.lumina(light: 0x93000A, dark: 0xFFDAD6)

  static let scrim = Color.lumina(light: 0x3D2F38, dark: 0x000000)

  // MARK: - 渐变（卡片 / FAB / 背景点缀）
  static func primaryGradient(colorScheme: ColorScheme) -> LinearGradient {
    if colorScheme == .dark {
      return LinearGradient(
        colors: [Color(hex: 0xD878A8), Color(hex: 0xA84878)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
    return LinearGradient(
      colors: [Color(hex: 0xE088A8), Color(hex: 0xC45C8A)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  static func inspirationGradient(colorScheme: ColorScheme) -> LinearGradient {
    if colorScheme == .dark {
      return LinearGradient(
        colors: [Color(hex: 0x5C2848), Color(hex: 0x3A1830)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
    return LinearGradient(
      colors: [Color(hex: 0xF0B8D0), Color(hex: 0xE8C8E0), Color(hex: 0xD8B8E8)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  static func screenAccentGradient(colorScheme: ColorScheme) -> LinearGradient {
    if colorScheme == .dark {
      return LinearGradient(
        colors: [Color(hex: 0x161218), Color(hex: 0x1F1520)],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    return LinearGradient(
      colors: [Color(hex: 0xFFF5F8), Color(hex: 0xFBF7F9), Color(hex: 0xF8F0F8)],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  /// 日历月历卡片：顶部淡粉紫晕染，底部回落到卡片底色
  static func calendarMonthCardGradient(colorScheme: ColorScheme) -> LinearGradient {
    if colorScheme == .dark {
      return LinearGradient(
        colors: [
          Color(hex: 0x3A2840).opacity(0.95),
          Color(hex: 0x261C28).opacity(0.85),
          Color(hex: 0x1F1A22)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
    return LinearGradient(
      colors: [
        Color(hex: 0xFFE8F2),
        Color(hex: 0xFAF2F8),
        Color(hex: 0xFFFFFF)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
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
  static let sm: CGFloat = 8
  static let md: CGFloat = 16
  static let lg: CGFloat = 20
  static let xl: CGFloat = 24
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
    modifier(LuminaScreenBackgroundModifier())
  }

  func luminaSoftShadow() -> some View {
    modifier(LuminaShadowModifier(intensity: .soft))
  }

  func luminaFABShadow() -> some View {
    modifier(LuminaShadowModifier(intensity: .fab))
  }
}

private struct LuminaScreenBackgroundModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content.background {
      LuminaColor.screenAccentGradient(colorScheme: colorScheme)
        .ignoresSafeArea()
    }
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
        color: softShadowColor(opacity: colorScheme == .dark ? 0.4 : 0.06),
        radius: colorScheme == .dark ? 8 : 12,
        x: 0,
        y: colorScheme == .dark ? 2 : 4
      )
    case .fab:
      content.shadow(
        color: softShadowColor(opacity: colorScheme == .dark ? 0.5 : 0.1),
        radius: colorScheme == .dark ? 14 : 16,
        x: 0,
        y: colorScheme == .dark ? 4 : 8
      )
      .shadow(
        color: LuminaColor.primary.opacity(colorScheme == .dark ? 0.25 : 0.22),
        radius: 14,
        x: 0,
        y: 6
      )
    }
  }

  private func softShadowColor(opacity: Double) -> Color {
    if colorScheme == .dark {
      return Color.black.opacity(opacity)
    }
    return LuminaColor.primary.opacity(opacity * 0.55)
  }
}

/// 根视图主题：背景、强调色、导航栏/列表外观
struct LuminaRootThemeModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .tint(LuminaColor.primary)
      .luminaScreenBackground()
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
