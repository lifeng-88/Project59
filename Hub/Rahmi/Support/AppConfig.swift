//
//  AppConfig.swift
//  Rahmi
//

import Foundation

final class AppConfig: @unchecked Sendable {
    static let shared = AppConfig()

    private static let channelKey = "ChannelId"

    /// Info.plist `ChannelId` 未配置或无效时的渠道 ID。**DEBUG：IOS10052（价目/配置调试）；Release：IOS10055。**
    static var buildDefaultChannelId: String {
        "IOS10055"
    }

    private init() {}

    func getChannel() async -> String {
        if let v = Bundle.main.object(forInfoDictionaryKey: Self.channelKey) as? String {
            let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty, !(t.hasPrefix("$(") && t.hasSuffix(")")) { return t }
        }
        return Self.buildDefaultChannelId
    }
}
