import Foundation

/// C 面 H5 地址：远端 `app_config` → 本地缓存 → Info.plist `CFaceURL` → 默认 landing + channel。
enum HubCFaceConfig {
    private static let infoKey = "CFaceURL"
    private static let defaultLandingBase = "https://silkflow.xin/h5/landing"

    static func resolveURL(remoteURLString: String?) -> URL? {
        if let url = normalizedURL(from: remoteURLString) {
            return landingURLWithConfiguredChannel(base: url)
        }
        if let cached = VersionConfigStore.readPersistedSurfaceWebURL(),
           let url = normalizedURL(from: cached) {
            return landingURLWithConfiguredChannel(base: url)
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String,
           let url = normalizedURL(from: plist) {
            return landingURLWithConfiguredChannel(base: url)
        }
        return defaultLandingURL()
    }

    static func defaultLandingURL() -> URL? {
        guard let base = normalizedURL(from: defaultLandingBase) else { return nil }
        return landingURLWithConfiguredChannel(base: base)
    }

    static func configuredChannelId() -> String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "AppChannel") as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) {
                return trimmed
            }
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "ChannelId") as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) {
                return trimmed
            }
        }
        return AppConfig.buildDefaultChannelId
    }

    private static func landingURLWithConfiguredChannel(base: URL) -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base
        }
        var items = components.queryItems ?? []
        if items.contains(where: { $0.name == "channel" && ($0.value?.isEmpty == false) }) {
            return components.url ?? base
        }
        items.removeAll { $0.name == "channel" }
        items.append(URLQueryItem(name: "channel", value: configuredChannelId()))
        components.queryItems = items
        return components.url ?? base
    }

    private static func normalizedURL(from raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }
        return URL(string: trimmed)
    }
}
