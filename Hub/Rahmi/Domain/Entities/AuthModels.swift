//
//  AuthModels.swift
//  glam
//
//  Created by Dev on 2026/1/18.
//

import Foundation

/// 登录请求模型，与 `LoginReq`（proto）字段一致；HTTP JSON 见 `RmIdentityWireTransport.login`（snake_case 键名）。
/// `push_id`：冷启动若已拿到 APNs token 则随登录一并上传；否则仍可在登录成功后走 `POST /v1/push_id` 补报。
struct LoginRequest: Codable {
    let devId: String
    let source: String?
    let channel: String?
    let pushId: String?
    let version: String
    let afId: String?
    let adId: String?
    let afAttributionJson: String?

    init(
        devId: String,
        source: String?,
        channel: String?,
        pushId: String? = nil,
        version: String,
        afId: String? = nil,
        adId: String? = nil,
        afAttributionJson: String? = nil
    ) {
        self.devId = devId
        self.source = source
        self.channel = channel
        self.pushId = pushId
        self.version = version
        self.afId = afId
        self.adId = adId
        self.afAttributionJson = afAttributionJson
    }

    enum CodingKeys: String, CodingKey {
        case devId = "dev_id"
        case source
        case channel
        case pushId = "push_id"
        case version
        case afId = "af_id"
        case adId = "ad_id"
        case afAttributionJson = "af_attribution_json"
    }
}

/// 登录响应模型
struct LoginResponse: Codable {
    let userid: String
    let accessToken: String
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case userid
        case accessToken
        case refreshToken
    }
}

/// 认证信息模型
struct AuthInfo {
    let userid: String
    let accessToken: String
    let refreshToken: String
    
    init(userid: String, accessToken: String, refreshToken: String) {
        self.userid = userid
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
    
    init(from response: LoginResponse) {
        self.userid = response.userid
        self.accessToken = response.accessToken
        self.refreshToken = response.refreshToken
    }
}
