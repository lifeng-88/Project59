import Foundation
import WebKit

enum HubCFaceURLConfig {
    static func channel(from url: URL) -> String? {
        guard let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "channel" })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty else { return nil }
        return raw
    }
}

enum HubH5Config {
    private(set) static var pageChannel: String?

    static let appDisplayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Hub"

    static var buildConfigurationLabel: String {
        #if DEBUG
        return "Debug"
        #else
        return "Release"
        #endif
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var channel: String? {
        pageChannel ?? plistChannel ?? AppConfig.buildDefaultChannelId
    }

    static var privacyURL: URL? {
        ResBaseURL.privacyPolicyURL
    }

    static var debugLogging: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static func configure(pageURL: URL) {
        pageChannel = HubCFaceURLConfig.channel(from: pageURL)
    }

    static func configureWebViewInspectability(_ webView: WKWebView) {
        if #available(iOS 16.4, *) {
            #if DEBUG
            webView.isInspectable = true
            #endif
        }
    }

    private static var plistChannel: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "ChannelId") as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }
        return trimmed
    }
}

extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
