//
//  ResBaseURL.swift
//  glam
//
//  静态资源基地址：Privacy Policy、Terms & Conditions 等 H5 页。默认 http://127.0.0.1。
//

import Combine
import Foundation

enum ResBaseURL {
    private static let infoKey = "ResBaseURL"
    
    /// 当前生效的资源基地址
    /// 优先级：Info.plist(ResBaseURL) > 默认值
    static var effective: String {
        if let value = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) {
                return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
            }
        }
        return "https://res.silkflow.xin";
    }

    /// Privacy Policy 页面 URL（H5，固定链接）
    static var privacyPolicyURL: URL {
        URL(string: "https://res.silkflow.xin/rahmi/rahmi-privacy.html")!
    }

    /// 用户协议页面 URL（H5，固定链接）
    static var termsAndConditionsURL: URL {
        URL(string: "https://res.silkflow.xin/rahmi/rahmi-user-agreement.html")!
    }

    /// 渠道远程配置：`{ResBaseURL}/config/{channel_id}.json`（AppsFlyer Apple App ID、Dev Key 等）
    static func channelConfigURL(for channelId: String) -> URL? {
        let id = channelId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }
        let base = effective.hasSuffix("/") ? String(effective.dropLast()) : effective
        let path = base.hasPrefix("http") ? "\(base)/config/\(id).json" : "http://\(base)/config/\(id).json"
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        return URL(string: encoded)
    }

    static var cFaceURLTemplate: URL {
        HubCFaceConfig.resolveURL(remoteURLString: nil)
            ?? URL(string: "https://silkflow.xin/h5/landing?channel=IOS10057")!
    }

    /// Hub C 面 WebView 入口（同步，不含 `did`）；加载时用 `pageURL` 拼 `did`。
    static var cFaceURL: URL {
        cFaceURLTemplate
    }

    static func cFaceLandingURL(deviceId: String) -> URL {
        urlAppendingDeviceId(cFaceURLTemplate, deviceId: deviceId)
    }

    static func urlAppendingDeviceId(_ url: URL, deviceId: String) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "did" }
        items.append(URLQueryItem(name: "did", value: deviceId))
        components.queryItems = items
        return components.url ?? url
    }
}
