//
//  RmRemoteFeatureConfigAPI.swift
//  Rahmi
//
//  GET /v1/app_config — 对齐 ReelMix GetAppConfigReq（dev_id/source/channel/version/af_attribution_json）
//

import Foundation

/// 与 `GetAppConfigReq` 一致（不含 login 的 afId/adId）。
struct AppConfigRequest {
    let devId: String
    let source: String?
    let channel: String?
    let version: String
    let afAttributionJson: String?

    func toRequestParameters() -> [String: Any] {
        var params: [String: Any] = [
            "dev_id": devId,
            "version": version
        ]
        if let source { params["source"] = source }
        if let channel { params["channel"] = channel }
        if let afAttributionJson, !afAttributionJson.isEmpty {
            params["af_attribution_json"] = afAttributionJson
        }
        return params
    }
}

struct AppConfigResponse: Decodable {
    /// 1：直链 IAP / Hub 壳 Lumina；2：支付 Sheet / Hub 壳 Rahmi
    let type: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case rechargePresentationType = "recharge_presentation_type"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fromTypeKey = Self.decodeFlexibleInt(from: c, forKey: .type)
        let fromSnake = Self.decodeFlexibleInt(from: c, forKey: .rechargePresentationType)
        type = fromTypeKey ?? fromSnake
    }

    private static func decodeFlexibleInt(from c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Int? {
        if let v = try? c.decode(Int.self, forKey: key) { return v }
        if let s = try? c.decode(String.self, forKey: key), let v = Int(s) { return v }
        if let i32 = try? c.decode(Int32.self, forKey: key) { return Int(i32) }
        return nil
    }
}

enum RmAppConfigAPI {
    static func fetchAppConfig(request: AppConfigRequest) async -> Result<AppConfigResponse, AppError> {
        await RmHTTPGatewayActor.shared.request(
            "/v1/app_config",
            method: .get,
            parameters: request.toRequestParameters(),
            requiresAuth: false
        )
    }
}
