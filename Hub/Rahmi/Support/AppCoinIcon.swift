//
//  AppCoinIcon.swift
//  Rahmi
//
//  应用内统一金币图标：`Assets.xcassets` 中 `AppCoinGold`（带透明底 PNG）。
//

import SwiftUI

/// 应用内统一金币图标（位图资源 `AppCoinGold`）
struct AppCoinIcon: View {
    /// 外接正方形边长
    var size: CGFloat = 17
    /// 保留以相容舊呼叫點；素材自帶星形，不再疊加文字。
    var symbol: String = "S"

    var body: some View {
        Image("AppCoinGold")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: Color.black.opacity(0.22), radius: size * 0.12, y: size * 0.06)
    }
}

#if DEBUG
struct AppCoinIcon_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            AppCoinIcon(size: 15)
            AppCoinIcon(size: 17)
            AppCoinIcon(size: 22)
        }
        .padding()
        .background(Color.black)
    }
}
#endif
