//
//  AppTheme.swift
//  Rahmi
//
//  色板对齐 `Assets.xcassets/AppIcon.appiconset/icon.png`：
//  深午夜紫蓝底、霓虹粉（左翼）、电青（右翼/粒子）、电路纹紫；金币语义仍用 `secondary` 金黄。
//

import SwiftUI

enum AppTheme {
    /// 图标底：近 `#0F0B2D`～`#1A1645` 的午夜紫蓝
    static let background = Color(red: 15 / 255, green: 11 / 255, blue: 45 / 255)
    static let surfaceDim = Color(red: 15 / 255, green: 11 / 255, blue: 45 / 255)
    static let surfaceContainer = Color(red: 26 / 255, green: 20 / 255, blue: 56 / 255)
    static let surfaceContainerLow = Color(red: 20 / 255, green: 16 / 255, blue: 48 / 255)
    static let surfaceContainerHigh = Color(red: 34 / 255, green: 27 / 255, blue: 62 / 255)
    static let surfaceContainerHighest = Color(red: 42 / 255, green: 33 / 255, blue: 72 / 255)
    static let surfaceVariant = Color(red: 42 / 255, green: 33 / 255, blue: 72 / 255)

    /// 主品牌：霓虹粉紫（图标左翼实色光）
    static let primary = Color(red: 255 / 255, green: 105 / 255, blue: 210 / 255)
    /// 深品红紫，与 primary 拉渐变
    static let primaryDim = Color(red: 168 / 255, green: 38 / 255, blue: 210 / 255)
    /// 金币 / 待支付等高亮（图标非主色，保留可读「金额」语义）
    static let secondary = Color(red: 255 / 255, green: 215 / 255, blue: 9 / 255)
    static let onSurface = Color(red: 236 / 255, green: 234 / 255, blue: 252 / 255)
    static let onSurfaceVariant = Color(red: 168 / 255, green: 164 / 255, blue: 198 / 255)
    /// 电路走线感紫灰 `#3B2F63` 一带
    static let outlineVariant = Color(red: 72 / 255, green: 58 / 255, blue: 112 / 255)

    /// 与 `primary` 同系的强调粉（标签/反馈等）
    static let neonPink = Color(red: 255 / 255, green: 68 / 255, blue: 204 / 255)
    /// 图标右翼线框青 `#00E8FF` 一带，需双 accent 时用（如渐变、描边）
    static let accentCyan = Color(red: 0 / 255, green: 232 / 255, blue: 255 / 255)

    static let tabBarBackground = Color(red: 22 / 255, green: 17 / 255, blue: 52 / 255).opacity(0.92)

    static let primaryGradient = LinearGradient(
        colors: [accentCyan.opacity(0.92), primary, primaryDim],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let premiumButtonGradient = LinearGradient(
        colors: [
            accentCyan,
            primary,
            primaryDim
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
