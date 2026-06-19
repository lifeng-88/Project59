//
//  RmHTTPGatewayActor.swift
//  glam
//
//  Created by Dev on 2026/1/18.
//

import Combine
import Foundation
import CFNetwork

/// `CFNetworkCopySystemProxySettings` / `connectionProxyDictionary` 键名（iOS 上部分 `kCFNetworkProxies*` 常量不可用）
private enum RmHTTPProxySettingsKey {
    static let httpEnable = "HTTPEnable"
    static let httpsEnable = "HTTPSEnable"
    static let socksEnable = "SOCKSEnable"
    static let httpProxy = "HTTPProxy"
    static let httpPort = "HTTPPort"
    static let httpsProxy = "HTTPSProxy"
    static let httpsPort = "HTTPSPort"
    static let socksProxy = "SOCKSProxy"
    static let socksPort = "SOCKSPort"
}

/// API 客户端
actor RmHTTPGatewayActor {
    static let shared = RmHTTPGatewayActor()
    
    private var baseURL: String {
        customBaseURL ?? APIBaseURL.effective
    }
    /// 测试或指定 base 时覆盖，nil 时使用 APIBaseURL.effective（默认 http://127.0.0.1）
    private let customBaseURL: String?
    private let session: URLSession
    private var accessToken: String?
    
    private init(baseURL: String? = nil) {
        self.customBaseURL = baseURL
        let configuration = Self.makeAPIURLSessionConfiguration()
        self.session = URLSession(configuration: configuration)
    }

    /// API 专用 `URLSession`：绕过系统 HTTP(S)/SOCKS 代理直连。
    /// Simulator 继承 Mac 上 Clash/Surge（127.0.0.1:7897 等）时，代理未运行会走 `lo0` 并 TLS -9816/-1200。
    private static func makeAPIURLSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        if #available(iOS 13.0, *) {
            configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        }
        configuration.connectionProxyDictionary = [
            RmHTTPProxySettingsKey.httpEnable: 0,
            RmHTTPProxySettingsKey.httpsEnable: 0,
            RmHTTPProxySettingsKey.socksEnable: 0
        ]
        if let proxyNote = describeActiveSystemProxy() {
            print("ℹ️ [RmHTTPGatewayActor] 系统代理 \(proxyNote)；API 请求已配置为直连（不经过本地代理）")
        }
        return configuration
    }

    private static func describeActiveSystemProxy() -> String? {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        var parts: [String] = []
        if (settings[RmHTTPProxySettingsKey.httpEnable] as? Int) == 1,
           let host = settings[RmHTTPProxySettingsKey.httpProxy] as? String {
            let port = settings[RmHTTPProxySettingsKey.httpPort] as? Int ?? 0
            parts.append("HTTP \(host):\(port)")
        }
        if (settings[RmHTTPProxySettingsKey.httpsEnable] as? Int) == 1,
           let host = settings[RmHTTPProxySettingsKey.httpsProxy] as? String {
            let port = settings[RmHTTPProxySettingsKey.httpsPort] as? Int ?? 0
            parts.append("HTTPS \(host):\(port)")
        }
        if (settings[RmHTTPProxySettingsKey.socksEnable] as? Int) == 1,
           let host = settings[RmHTTPProxySettingsKey.socksProxy] as? String {
            let port = settings[RmHTTPProxySettingsKey.socksPort] as? Int ?? 0
            parts.append("SOCKS \(host):\(port)")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }
    
    /// 创建测试用的 API 客户端（使用指定的 baseURL）
    static func createForTesting(baseURL: String) -> RmHTTPGatewayActor {
        return RmHTTPGatewayActor(baseURL: baseURL)
    }
    
    /// 设置访问令牌（去首尾空白；空串视为未登录，避免发出 `Bearer ` 遭 OpenResty 401）
    func setAccessToken(_ token: String?) {
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        accessToken = trimmed.isEmpty ? nil : trimmed
    }
    
    /// 获取访问令牌
    func getAccessToken() -> String? {
        return accessToken
    }
    
    /// 获取当前使用的 baseURL（用于调试）
    func getBaseURL() -> String {
        return baseURL
    }
    
    /// 发送请求（带自动 Token 刷新）
    /// - Parameter requiresAuth: 为 false 时不带 Authorization 头，用于公开接口（如 /v1/locations/ip）
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        retryOnUnauthorized: Bool = true,
        requiresAuth: Bool = true
    ) async -> Result<T, AppError> {
        // 首次尝试请求
        let result: Result<T, AppError> = await performRequest(endpoint: endpoint, method: method, parameters: parameters, headers: headers, requiresAuth: requiresAuth)
        
        // 接口返回 401（token 过期）时先尝试刷新 token，刷新失败则由 TokenManager 发通知、由 app 触发重新登录
        if case .failure(.unauthorized) = result, retryOnUnauthorized, requiresAuth {
            // 跳过刷新 Token 的接口，避免死循环
            if endpoint == "/v1/refresh" || endpoint == "/v1/login" {
                return result
            }
            
            // 尝试刷新 Token
            let tokenManager = TokenManager.shared
            let refreshResult = await tokenManager.refreshTokenIfNeeded()
            
            switch refreshResult {
            case .success(let authInfo):
                // 刷新成功，更新 Token 并重试请求
                await setAccessToken(authInfo.accessToken)
                return await performRequest(endpoint: endpoint, method: method, parameters: parameters, headers: headers, requiresAuth: requiresAuth) as Result<T, AppError>
            case .failure:
                // 刷新失败，返回未授权错误
                return .failure(.unauthorized)
            }
        }
        
        return result
    }
    
    /// 执行实际的 HTTP 请求
    private func performRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        parameters: [String: Any]?,
        headers: [String: String]?,
        requiresAuth: Bool = true
    ) async -> Result<T, AppError> {
        guard let url = URL(string: baseURL + endpoint) else {
            return .failure(.networkError("Invalid URL"))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 仅当需要鉴权时添加 Authorization 头（公开接口如 IP 定位不加）；无有效 token 时不发请求，避免网关 HTML 401
        if requiresAuth {
            guard let token = accessToken, !token.isEmpty else {
                print("❌ [RmHTTPGatewayActor] requiresAuth 但未设置有效 accessToken，跳过请求: \(endpoint)")
                return .failure(.unauthorized)
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 添加自定义头
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 添加请求体
        if let parameters = parameters, method != .get {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                // 调试：打印请求体
                if let jsonData = try? JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("🌐 [RmHTTPGatewayActor] Request body:")
                    print(jsonString)
                }
            } catch {
                return .failure(.encodingError(error.localizedDescription))
            }
        }
        
        // 添加 GET 请求的查询参数
        if let parameters = parameters, method == .get {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
            if let newURL = components?.url {
                request.url = newURL
            }
        }
        
        do {
            // 调试：打印请求信息
            print("🌐 [RmHTTPGatewayActor] ========== 请求信息 ==========")
            print("🌐 [RmHTTPGatewayActor] BaseURL: \(baseURL)")
            print("🌐 [RmHTTPGatewayActor] Endpoint: \(endpoint)")
            print("🌐 [RmHTTPGatewayActor] Method: \(method.rawValue)")
            // 打印最终URL（包含查询参数）
            if let finalURL = request.url {
                print("🌐 [RmHTTPGatewayActor] Full URL: \(finalURL.absoluteString)")
            } else {
                print("🌐 [RmHTTPGatewayActor] Full URL: \(url.absoluteString)")
            }
            
            // 打印请求头
            if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
                print("🌐 [RmHTTPGatewayActor] 请求头:")
                for (key, value) in headers {
                    if key == "Authorization" {
                        print("   - \(key): Bearer \(value.replacingOccurrences(of: "Bearer ", with: "").prefix(50))...")
                    } else {
                        print("   - \(key): \(value)")
                    }
                }
            } else {
                print("🌐 [RmHTTPGatewayActor] 请求头: 无")
            }
            
            // 打印请求参数
            if let parameters = parameters, !parameters.isEmpty {
                print("🌐 [RmHTTPGatewayActor] 请求参数:")
                if let jsonData = try? JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                } else {
                    print("   \(parameters)")
                }
            } else {
                print("🌐 [RmHTTPGatewayActor] 请求参数: 无")
            }
            
            // 打印请求体（如果有）
            if let body = request.httpBody {
                if let bodyString = String(data: body, encoding: .utf8) {
                    print("🌐 [RmHTTPGatewayActor] 请求体:")
                    print(bodyString)
                } else {
                    print("🌐 [RmHTTPGatewayActor] 请求体: 二进制数据 (\(body.count) bytes)")
                }
            }
            
            if let token = accessToken {
                print("🌐 [RmHTTPGatewayActor] Token: \(token.prefix(50))... (长度: \(token.count))")
            } else {
                print("🌐 [RmHTTPGatewayActor] Token: 无")
            }
            print("🌐 [RmHTTPGatewayActor] ==============================")
            
            let (data, response) = try await Self.dataWithTransientRetry(
                session: session,
                request: request,
                label: "\(method.rawValue) \(endpoint)"
            )
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [RmHTTPGatewayActor] Invalid response type")
                return .failure(.invalidResponse)
            }
            
            // 调试：打印响应信息
            print("📡 [RmHTTPGatewayActor] ========== 响应信息 ==========")
            print("📡 [RmHTTPGatewayActor] Status Code: \(httpResponse.statusCode)")
            print("📡 [RmHTTPGatewayActor] URL: \(url.absoluteString)")
            
            // 打印响应头
            if !httpResponse.allHeaderFields.isEmpty {
                print("📡 [RmHTTPGatewayActor] 响应头:")
                for (key, value) in httpResponse.allHeaderFields {
                    print("   - \(key): \(value)")
                }
            }
            
            // 打印响应体
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 [RmHTTPGatewayActor] 响应体 (完整):")
                print(responseString)
                print("📡 [RmHTTPGatewayActor] 响应体长度: \(responseString.count) 字符, 数据大小: \(data.count) 字节")
                
                // 如果是JSON格式，尝试美化输出
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                   let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    print("📡 [RmHTTPGatewayActor] 响应体 (格式化JSON):")
                    print(prettyString)
                }
            } else {
                print("⚠️ [RmHTTPGatewayActor] 响应数据不是有效的UTF-8字符串, 大小: \(data.count) 字节")
                // 尝试打印十六进制（仅前1000字节）
                let hexString = data.prefix(1000).map { String(format: "%02x", $0) }.joined(separator: " ")
                print("📡 [RmHTTPGatewayActor] 响应数据 (hex, 前1000字节): \(hexString)")
            }
            
            // 如果是错误响应，额外打印详细信息
            if httpResponse.statusCode >= 400 {
                print("❌ [RmHTTPGatewayActor] ========== 错误详情 ==========")
                print("❌ [RmHTTPGatewayActor] HTTP状态码: \(httpResponse.statusCode)")
                print("❌ [RmHTTPGatewayActor] 请求URL: \(url.absoluteString)")
                print("❌ [RmHTTPGatewayActor] 请求方法: \(method.rawValue)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ [RmHTTPGatewayActor] 错误响应体:")
                    print(responseString)
                }
                print("❌ [RmHTTPGatewayActor] ==============================")
            }
            
            print("📡 [RmHTTPGatewayActor] ==============================")
            
            // 处理 HTTP 状态码
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                return .failure(.unauthorized)
            case 404:
                return .failure(.notFound)
            case 400...499:
                // 尝试解析错误消息
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    return .failure(.serverError(code: httpResponse.statusCode, message: errorResponse.message))
                }
                return .failure(.serverError(code: httpResponse.statusCode, message: ""))
            case 500...599:
                // 尝试解析详细的错误消息
                if let responseString = String(data: data, encoding: .utf8),
                   let errorData = responseString.data(using: .utf8),
                   let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: errorData) {
                    return .failure(.serverError(code: httpResponse.statusCode, message: errorResponse.message))
                }
                return .failure(.serverError(code: httpResponse.statusCode, message: "Server error. Please try again later."))
            default:
                return .failure(.serverError(code: httpResponse.statusCode, message: ""))
            }
            
            // 解析响应数据
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let result = try decoder.decode(T.self, from: data)
                print("✅ [RmHTTPGatewayActor] Successfully decoded response for \(url.absoluteString)")
                // 注意：解码后的数据已经在原始响应数据中打印了
                return .success(result)
            } catch {
                print("❌ [RmHTTPGatewayActor] Decoding error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ [RmHTTPGatewayActor] Failed to decode response data (完整内容):")
                    print(responseString)
                } else {
                    print("❌ [RmHTTPGatewayActor] Response data is not valid UTF-8, size: \(data.count) bytes")
                }
                // 如果解析失败，尝试解析为错误响应
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    return .failure(.serverError(code: httpResponse.statusCode, message: errorResponse.message))
                }
                return .failure(.decodingError(error.localizedDescription))
            }
        } catch {
            Self.logURLSessionFailure(error, label: "request \(method.rawValue) \(endpoint)")
            return .failure(.networkError(error.localizedDescription))
        }
    }

    /// 控制台诊断：区分 DNS(-1003)、断连(-1005)、超时、TLS(-1200) 等，便于与系统 `nw_` 日志对照（与 glam `RmHTTPGatewayActor` 一致）
    private static func logURLSessionFailure(_ error: Error, label: String) {
        if let urlError = error as? URLError {
            let code = urlError.code.rawValue
            let failing = urlError.failureURLString ?? "(nil)"
            print("❌ [RmHTTPGatewayActor] 传输失败 [\(label)] URLError rawValue=\(code) \(urlError.code) failingURL=\(failing) — \(urlError.localizedDescription)")
            if let underlying = urlError.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("   underlying: domain=\(underlying.domain) code=\(underlying.code) — \(underlying.localizedDescription)")
                let sslCode = underlying.userInfo["_kCFStreamErrorCodeKey"] as? Int
                    ?? underlying.userInfo["_CFStreamErrorCodeKey"] as? Int
                if sslCode == -9816 {
                    print("   ssl: errSSLClosedAbort / 握手被对端或中间代理中断（-9816）")
                }
            }
            let nwPath = urlError.userInfo["_NSURLErrorNWPathKey"] as? String
            if urlError.code == .secureConnectionFailed {
                if let nwPath, nwPath.contains("proxy") || nwPath.contains("lo0") {
                    print("   hint: 请求经本机代理(lo0)转发。Mac 开 Clash/Surge 但客户端未运行时常见 TLS -1200。API 已绕过系统代理直连；若仍失败请关闭系统 HTTP 代理或启动代理软件。")
                } else {
                    print("   hint: TLS 失败常见于证书未生效/过期、设备时间不准、VPN/抓包代理、或 Simulator 网络异常。")
                }
            }
        } else {
            print("❌ [RmHTTPGatewayActor] 传输失败 [\(label)] \(type(of: error)): \(error.localizedDescription)")
        }
    }

    /// 对冷启动/瞬时网络与偶发 TLS 握手失败做一次短延迟重试（不重试 401/解码等业务错误）
    private static func dataWithTransientRetry(
        session: URLSession,
        request: URLRequest,
        label: String
    ) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            guard shouldRetryTransientURLSessionError(error) else { throw error }
            print("⚠️ [RmHTTPGatewayActor] 瞬时网络错误，1.2s 后重试 [\(label)]")
            try await Task.sleep(nanoseconds: 1_200_000_000)
            return try await session.data(for: request)
        }
    }

    private static func shouldRetryTransientURLSessionError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .secureConnectionFailed,
             .cannotLoadFromNetwork,
             .networkConnectionLost,
             .notConnectedToInternet,
             .timedOut,
             .dnsLookupFailed,
             .cannotFindHost,
             .cannotConnectToHost:
            return true
        default:
            return false
        }
    }
    
    /// 上传文件（multipart/form-data）
    func uploadFile<T: Decodable>(
        _ endpoint: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        parameters: [String: String]? = nil,
        progressHandler: ((Double) -> Void)? = nil,
        retryOnUnauthorized: Bool = true
    ) async -> Result<T, AppError> {
        // 首次尝试上传
        let result: Result<T, AppError> = await performFileUpload(
            endpoint: endpoint,
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType,
            parameters: parameters,
            progressHandler: progressHandler
        )
        
        // 如果是 401 错误且允许重试，尝试刷新 Token
        if case .failure(.unauthorized) = result, retryOnUnauthorized {
            if endpoint == "/v1/refresh" || endpoint == "/v1/login" {
                return result
            }
            
            let tokenManager = TokenManager.shared
            let refreshResult = await tokenManager.refreshTokenIfNeeded()
            
            switch refreshResult {
            case .success(let authInfo):
                await setAccessToken(authInfo.accessToken)
                return await performFileUpload(
                    endpoint: endpoint,
                    fileData: fileData,
                    fileName: fileName,
                    mimeType: mimeType,
                    parameters: parameters,
                    progressHandler: progressHandler
                ) as Result<T, AppError>
            case .failure:
                return .failure(.unauthorized)
            }
        }
        
        return result
    }
    
    /// 执行文件上传
    private func performFileUpload<T: Decodable>(
        endpoint: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        parameters: [String: String]?,
        progressHandler: ((Double) -> Void)?
    ) async -> Result<T, AppError> {
        guard let url = URL(string: baseURL + endpoint) else {
            return .failure(.networkError("Invalid URL"))
        }
        
        // 创建 multipart/form-data 请求体
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 添加认证头
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 构建 multipart body
        var body = Data()
        
        // 添加文本参数
        if let parameters = parameters {
            for (key, value) in parameters {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
        }
        
        // 添加文件
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // 注意：不要设置 request.httpBody，因为 upload(for:from:) 会从 from 参数读取数据
        // 只需要设置 Content-Length
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        
        do {
            print("📤 [RmHTTPGatewayActor] Uploading file: \(fileName) (\(fileData.count) bytes) to \(url.absoluteString)")
            
            // 使用 URLSession.upload 上传文件
            // upload(for:from:) 会从 from 参数读取数据，所以不需要设置 httpBody
            let (data, response) = try await session.upload(for: request, from: body)
            
            // 如果有进度回调，在后台任务中模拟进度更新（实际应该使用 URLSessionTaskDelegate）
            if let progressHandler = progressHandler {
                // 由于 URLSession.upload 不直接支持进度回调，这里先发送完成进度
                // 实际项目中应该使用 URLSessionTaskDelegate 来获取真实进度
                Task {
                    await MainActor.run {
                        progressHandler(1.0)
                    }
                }
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            print("📡 [RmHTTPGatewayActor] Upload response: \(httpResponse.statusCode) for \(url.absoluteString)")
            
            // 处理 HTTP 状态码
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                return .failure(.unauthorized)
            case 404:
                return .failure(.notFound)
            case 400...499:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    return .failure(.serverError(code: httpResponse.statusCode, message: errorResponse.message))
                }
                return .failure(.serverError(code: httpResponse.statusCode, message: ""))
            case 500...599:
                return .failure(.serverError(code: httpResponse.statusCode, message: "Server error. Please try again later."))
            default:
                return .failure(.serverError(code: httpResponse.statusCode, message: ""))
            }
            
            // 解析响应数据
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let result = try decoder.decode(T.self, from: data)
                print("✅ [RmHTTPGatewayActor] Upload successful, decoded response")
                return .success(result)
            } catch {
                print("❌ [RmHTTPGatewayActor] Upload decoding error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ [RmHTTPGatewayActor] Response data: \(responseString)")
                }
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    return .failure(.serverError(code: httpResponse.statusCode, message: errorResponse.message))
                }
                return .failure(.decodingError(error.localizedDescription))
            }
        } catch {
            Self.logURLSessionFailure(error, label: "upload \(endpoint)")
            return .failure(.networkError(error.localizedDescription))
        }
    }
}

/// HTTP 方法
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// 错误响应模型
struct ErrorResponse: Decodable {
    let code: Int?
    let message: String
    let details: [String]?
    
    enum CodingKeys: String, CodingKey {
        case code
        case message
        case details
    }
}