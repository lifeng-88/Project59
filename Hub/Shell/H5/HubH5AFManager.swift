import Foundation

#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif

extension AFAttributionResult {
    var hubH5LoginParameters: [String: Any] {
        var params: [String: Any] = [:]
        if let source = source?.trimmedNonEmpty { params["source"] = source }
        if let afId = afId?.trimmedNonEmpty { params["afId"] = afId }
        if let adId = adId?.trimmedNonEmpty { params["adId"] = adId }
        if let attributionJson = attributionJson?.trimmedNonEmpty {
            params["afAttributionJson"] = attributionJson
        }
        return params
    }

    static func hubH5TimeoutFallbackParameters() -> [String: Any] {
        AFAttributionResult.timeoutFallback().hubH5LoginParameters
    }
}

/// Morph `MorphAFManager` 对齐：桥接 H5 与 Hub 现有 AF / 归因栈。
@MainActor
final class HubH5AFManager {
    static let shared = HubH5AFManager()

    private init() {}

    func markLoginCompleted() {
        Task { await RmThirdPartyAttributionBridge.shared.markLoginCompleted() }
    }

    func initAFAsync(channelId: String?) async {
        let channel = await resolvedChannel(channelId)
        await RmThirdPartyAttributionBridge.shared.initAFAsync(channelId: channel)
    }

    func prepareLoginAttribution(channelId: String?) async -> [String: Any] {
        let channel = await resolvedChannel(channelId)
        let (_, attribution) = await RmThirdPartyAttributionBridge.shared.prepareForFirstLaunch(channelId: channel)
        if let attribution {
            return attribution.hubH5LoginParameters
        }
        return AFAttributionResult.hubH5TimeoutFallbackParameters()
    }

    func logEvent(
        channelId: String?,
        eventName: String,
        values: [String: Any]?
    ) async -> [String: Any] {
        let trimmedEventName = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEventName.isEmpty else {
            return [
                "logged": false,
                "code": "INVALID_EVENT_NAME",
                "message": "Event name is empty."
            ]
        }

        let channel = await resolvedChannel(channelId)
        _ = await RmThirdPartyAttributionBridge.shared.initAFAsync(channelId: channel)

        let afValues = Self.normalizedEventValues(values)
        return await HubH5AFSDKBridge.logEvent(name: trimmedEventName, values: afValues.isEmpty ? nil : afValues)
    }

    private func resolvedChannel(_ channelId: String?) async -> String {
        if let channel = channelId?.trimmedNonEmpty { return channel }
        if let channel = HubH5Config.channel?.trimmedNonEmpty { return channel }
        return await AppConfig.shared.getChannel()
    }

    private static func normalizedEventValues(_ values: [String: Any]?) -> [String: Any] {
        guard let values else { return [:] }
        var result: [String: Any] = [:]
        for (key, value) in values {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedKey.isEmpty, let normalized = normalizedEventValue(value) else { continue }
            result[trimmedKey] = normalized
        }
        return result
    }

    private static func normalizedEventValue(_ value: Any) -> Any? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number
        case let bool as Bool:
            return bool
        case let int as Int:
            return int
        case let int8 as Int8:
            return int8
        case let int16 as Int16:
            return int16
        case let int32 as Int32:
            return int32
        case let int64 as Int64:
            return int64
        case let uint as UInt:
            return uint
        case let float as Float:
            return float
        case let double as Double:
            return double
        case let dict as [String: Any]:
            let nested = normalizedEventValues(dict)
            return nested.isEmpty ? nil : nested
        case let array as [Any]:
            let normalized = array.compactMap { normalizedEventValue($0) }
            return normalized.isEmpty ? nil : normalized
        default:
            return nil
        }
    }
}

enum HubH5AFSDKBridge {
    static func logEvent(name: String, values: [String: Any]?) async -> [String: Any] {
        #if canImport(AppsFlyerLib)
        return await withCheckedContinuation { continuation in
            AppsFlyerLib.shared().logEvent(
                name: name,
                values: values,
                completionHandler: { response, error in
                    if let error {
                        continuation.resume(returning: [
                            "logged": false,
                            "code": "AF_LOG_EVENT_FAILED",
                            "message": error.localizedDescription,
                            "eventName": name
                        ])
                        return
                    }
                    var payload: [String: Any] = [
                        "logged": true,
                        "eventName": name
                    ]
                    if let response, !response.isEmpty {
                        payload["response"] = response
                    }
                    continuation.resume(returning: payload)
                }
            )
        }
        #else
        _ = name
        _ = values
        return ["logged": true, "eventName": name]
        #endif
    }
}
