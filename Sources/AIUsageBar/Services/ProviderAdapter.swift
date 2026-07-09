import Foundation

// MARK: - Provider Adapter Protocol

/// 各 provider 的连接测试适配器
protocol ProviderAdapter {
    var providerType: ProviderAdapterType { get }
    var displayName: String { get }
    /// 测试连接
    func testConnection(apiKey: String, baseURL: String, model: String) async -> ConnectionTestResult
}

// MARK: - DeepSeek Adapter

final class DeepSeekAdapter: ProviderAdapter {
    let providerType: ProviderAdapterType = .deepseek
    let displayName = "DeepSeek"

    func testConnection(apiKey: String, baseURL: String, model: String) async -> ConnectionTestResult {
        await testOpenAICompatible(apiKey: apiKey, baseURL: baseURL, model: model, providerName: "DeepSeek")
    }
}

// MARK: - OpenAI Compatible Adapter

final class OpenAICompatibleAdapter: ProviderAdapter {
    let providerType: ProviderAdapterType = .openaiCompatible
    let displayName = "OpenAI Compatible"

    func testConnection(apiKey: String, baseURL: String, model: String) async -> ConnectionTestResult {
        await testOpenAICompatible(apiKey: apiKey, baseURL: baseURL, model: model, providerName: "API")
    }
}

// MARK: - Anthropic Adapter

final class AnthropicAdapter: ProviderAdapter {
    let providerType: ProviderAdapterType = .anthropic
    let displayName = "Anthropic"

    func testConnection(apiKey: String, baseURL: String, model: String) async -> ConnectionTestResult {
        // POST {baseURL}/v1/messages
        let urlStr = baseURL.hasSuffix("/") ? "\(baseURL)v1/messages" : "\(baseURL)/v1/messages"
        guard let url = URL(string: urlStr) else {
            return ConnectionTestResult(success: false, latencyMs: 0, model: model, message: "无效的 URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "ping"]],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10

        let start = Date()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let latency = Date().timeIntervalSince(start) * 1000
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    return ConnectionTestResult(success: true, latencyMs: latency, model: model,
                                                message: "✅ 连接成功 (¥{Int(latency)}ms)")
                } else {
                    return ConnectionTestResult(success: false, latencyMs: latency, model: model,
                                                message: "HTTP \(http.statusCode)")
                }
            }
            return ConnectionTestResult(success: false, latencyMs: latency, model: model, message: "未知响应")
        } catch {
            return ConnectionTestResult(success: false, latencyMs: 0, model: model, message: error.localizedDescription)
        }
    }
}

// MARK: - OpenRouter Adapter

final class OpenRouterAdapter: ProviderAdapter {
    let providerType: ProviderAdapterType = .openrouter
    let displayName = "OpenRouter"

    func testConnection(apiKey: String, baseURL: String, model: String) async -> ConnectionTestResult {
        await testOpenAICompatible(apiKey: apiKey, baseURL: baseURL, model: model, providerName: "OpenRouter")
    }
}

// MARK: - Shared Test Logic

private func testOpenAICompatible(
    apiKey: String, baseURL: String, model: String, providerName: String
) async -> ConnectionTestResult {
    let urlStr = baseURL.hasSuffix("/") ? "\(baseURL)v1/chat/completions" : "\(baseURL)/v1/chat/completions"
    guard let url = URL(string: urlStr) else {
        return ConnectionTestResult(success: false, latencyMs: 0, model: model, message: "无效的 URL")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    let body: [String: Any] = [
        "model": model,
        "messages": [["role": "user", "content": "ping"]],
        "max_tokens": 1,
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    request.timeoutInterval = 10

    let start = Date()
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        let latency = Date().timeIntervalSince(start) * 1000
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 200 {
                return ConnectionTestResult(success: true, latencyMs: latency, model: model,
                                            message: "✅ 连接成功 (\(Int(latency))ms)")
            } else {
                let bodyHint = String(data: data, encoding: .utf8)?.prefix(100) ?? ""
                return ConnectionTestResult(success: false, latencyMs: latency, model: model,
                                            message: "HTTP \(http.statusCode): \(bodyHint)")
            }
        }
        return ConnectionTestResult(success: false, latencyMs: latency, model: model, message: "未知响应")
    } catch {
        return ConnectionTestResult(success: false, latencyMs: 0, model: model, message: error.localizedDescription)
    }
}

// MARK: - Factory

enum ProviderAdapterFactory {
    static func adapter(for type: ProviderAdapterType) -> ProviderAdapter {
        switch type {
        case .deepseek:          return DeepSeekAdapter()
        case .anthropic:         return AnthropicAdapter()
        case .openrouter:        return OpenRouterAdapter()
        case .openaiCompatible:  return OpenAICompatibleAdapter()
        }
    }

    static func adapter(for providerTypeString: String) -> ProviderAdapter? {
        guard let type = ProviderAdapterType(rawValue: providerTypeString) else {
            return nil
        }
        return adapter(for: type)
    }
}
